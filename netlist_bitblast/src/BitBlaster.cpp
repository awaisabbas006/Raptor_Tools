/*
Copyright 2021-2024 Rapid Silicon

GPL License

Copyright (c) 2024 The Open-Source FPGA Foundation

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include "BitBlaster.h"

#include <uhdm/ElaboratorListener.h>
#include <uhdm/ExprEval.h>
#include <uhdm/NumUtils.h>
#include <uhdm/clone_tree.h>
#include <uhdm/containers.h>
#include <uhdm/uhdm.h>
#include <uhdm/uhdm_forward_decl.h>
#include <uhdm/uhdm_types.h>
#include <uhdm/vpi_visitor.h>

#include "Utils.h"

using namespace UHDM;

namespace BITBLAST {

std::string BitBlaster::filterIcarusSDFUnsupportedCharacters(
    const std::string &st) {
  std::string result;
  char c_1 = ' ';
  for (uint32_t i = 0; i < st.size(); i++) {
    char c = st[i];
    if (c == '\\' && c_1 == '\\') {
      result = result.substr(0, result.size()-1);
      result += "_";
    } else if (c == '.' || c == ':' || c == '/')
      result += "_";
    else
      result += c;
    c_1 = c;
  }
  return result;
}

void blastPorts(const VectorOfport *origPorts, VectorOfport *newPorts,
                Serializer &s, const std::string suffix) {
  for (port *p : *origPorts) {
    any *lowc = p->Low_conn();
    std::string_view port_name = lowc->VpiName();
    const ref_typespec *port_reftps = p->Typespec();
    const typespec *port_tps = port_reftps->Actual_typespec();
    uint64_t k = 1;
    if (port_tps->UhdmType() == uhdmlogic_typespec) {
      logic_typespec *ltps = (logic_typespec *)port_tps;
      bool invalidValue = false;
      if (ltps->Ranges()) {
        ExprEval eval;
        k = eval.size(ltps, invalidValue, nullptr, p, true);
      }
    }
    if (k > 1) {
      any *highc = p->High_conn();
      UHDM_OBJECT_TYPE high_conn_type = highc->UhdmType();
      if (high_conn_type == uhdmconstant) {
        constant *c = (constant *)highc;
        ExprEval eval;
        uint64_t val = eval.getValue(c);
        for (uint64_t i = 0; i < k; i++) {
          port *np = s.MakePort();
          np->VpiName(std::string(port_name) + suffix +
                      std::to_string(k - 1 - i));
          constant *cn = s.MakeConstant();
          cn->VpiSize(1);
          cn->VpiConstType(vpiBinaryConst);
          cn->VpiValue("BIN:" + std::to_string(val &= (1 << (k - 1 - i))));
          np->High_conn(cn);
          newPorts->push_back(np);
        }
      } else if (high_conn_type == uhdmoperation) {
        operation *oper = (operation *)highc;
        int index = 0;
        if (oper->Operands()) {
          for (any *op : *oper->Operands()) {
            port *np = s.MakePort();
            np->VpiName(std::string(port_name) + suffix +
                        std::to_string(oper->Operands()->size() - 1 - index));
            np->High_conn(op);
            newPorts->push_back(np);
            index++;
          }
        } else {
          // An operation with no operands is a high conn with .()
          // We leave it implicitely unconnected
          // DO NOT: newPorts->push_back(p);
        }
      }
    } else {
      newPorts->push_back(p);
    }
  }
}

// Bit blasts: LUT_K, RS_DSP, RS_BRAM instances
bool BitBlaster::bitBlast(const UHDM::any *object) {
  if (object == nullptr) return false;
  Serializer *s = object->GetSerializer();
  UHDM::UHDM_OBJECT_TYPE type = object->UhdmType();
  switch (type) {
    case UHDM_OBJECT_TYPE::uhdmdesign: {
      design *d = (design *)object;
      m_design = d;
      for (module_inst *top : *d->TopModules()) {
        bitBlast(top);
      }
      break;
    }
    case UHDM_OBJECT_TYPE::uhdmmodule_inst: {
      module_inst *c = (module_inst *)object;
      if (c->VpiTopModule()) {
        if (c->Modules()) {
          for (module_inst *m : *c->Modules()) {
            bitBlast(m);
          }
        }
      } else {
        std::string cellName = Utils::removeLibName(c->VpiDefName());
        c->VpiName(
            filterIcarusSDFUnsupportedCharacters(std::string(c->VpiName())));
        if (cellName == "LUT_K") {
          uint64_t k = 0;
          if (c->Param_assigns()) {
            for (param_assign *p : *c->Param_assigns()) {
              any *lhs = p->Lhs();
              any *rhs = p->Rhs();
              if (lhs->VpiName() == "K") {
                ExprEval eval;
                k = eval.getValue((expr *)rhs);
              }
            }
          }
          std::string blastedName = "LUT_K" + std::to_string(k);
          m_instanceCellMap.emplace(std::string(c->VpiName()), blastedName);
          c->VpiDefName(blastedName);
          if (auto origPorts = c->Ports()) {
            VectorOfport *newPorts = s->MakePortVec();
            blastPorts(origPorts, newPorts, *s, "");
            c->Ports(newPorts);
          }
        } else if (cellName.find("RS_DSP") != std::string::npos) {
          std::string blastedName = cellName + "_BLASTED";
          m_instanceCellMap.emplace(std::string(c->VpiName()), blastedName);
          c->VpiDefName(blastedName);
          if (auto origPorts = c->Ports()) {
            VectorOfport *newPorts = s->MakePortVec();
            blastPorts(origPorts, newPorts, *s, "");
            c->Ports(newPorts);
          }
        } else if (cellName.find("RS_TDP") != std::string::npos) {
          std::string blastedName = cellName + "_BLASTED";
          m_instanceCellMap.emplace(std::string(c->VpiName()), blastedName);
          c->VpiDefName(blastedName);
          if (auto origPorts = c->Ports()) {
            VectorOfport *newPorts = s->MakePortVec();
            blastPorts(origPorts, newPorts, *s, "_");
            c->Ports(newPorts);
          }
        }
      }
      break;
    }
    default: {
      std::cerr << "NOT HANDLED HANDLE: " << UhdmName(object->UhdmType())
                << "\n";
      exit(1);
      break;
    }
  }
  return true;
}

static std::string empty;
const std::string &BitBlaster::getCellType(const std::string &instance) {
  std::map<std::string, std::string>::iterator itr =
      m_instanceCellMap.find(instance);
  if (itr == m_instanceCellMap.end()) {
    return empty;
  } else {
    return (*itr).second;
  }
}

}  // namespace BITBLAST
