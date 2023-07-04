/*
 *
 * (c) Copyright 1999 - 2022 Verific Design Automation Inc.
 * All rights reserved.
 *
 * This source code belongs to Verific Design Automation Inc.
 * It is considered trade secret and confidential, and is not to be used
 * by parties who have not received written authorization
 * from Verific Design Automation Inc.
 *
 * Only authorized users are allowed to use, copy and modify
 * this software provided that the above copyright notice
 * remains in all copies of this software.
 *
 *
*/
#include <iostream>
#include <cstring>
#include "Array.h"          // Make class Array available

#include "VeriId.h"         // Definitions of all identifier definition tree nodes
#include "VeriCopy.h"       // Make class VeriMapForCopy available
#include "Map.h"            // Make class Map available
#include "VeriTreeNode.h"   // Definition of VeriTreeNode

#include "Message.h"        // Make message handlers available

#include "DataBase.h" // Make (hierarchical netlist) database API available
#include "VeriTreeNode.h"   // Definition of VeriTreeNode
#include "veri_file.h"      // Make verilog reader available
#include "VeriModule.h"     // Definition of a VeriModule and VeriPrimitive
#include "VeriExpression.h" // Definitions of all verilog expression tree nodes
#include "VeriModuleItem.h" // Definitions of all verilog module item tree nodes
#include "VeriMisc.h"       // Definitions of all extraneous verilog tree nodes (ie. range, path, strength, etc...)
#include "VeriStatement.h"  // Make VeriCaseStatement class available
#include "VeriVisitor.h"    // For visitor patterns
#include "VeriConstVal.h"   // Definitions of all constant expression tree nodes
#include "VeriScope.h"      // Symbol table of locally declared identifiers
#include "Strings.h"        // Definition of class to manipulate copy, concatenate, create etc...
#include "veri_prune.h" 

#define VERI_INOUT 329
#define VERI_INPUT 330
#define VERI_OUTPUT 346
#define VERI_WIRE 392
#define IN_DIR 0
#define OUT_DIR 1
#define INOUT_DIR 2

#ifdef USE_COMREAD
#include "Commands.h"
#include "ComRead.h"
#endif

#ifdef VERIFIC_NAMESPACE
using namespace Verific ;
#endif

bool isimod(std::string mod)
{
    gb_constructs gb;
    for (const auto& element : gb.imods)
    {
        if (mod == element) {
            return true; }
    }
    return false;
}


////////////////////////////////////////////////////////////////////////////

int prune_verilog (const char *file_name, const char *out_file_name, const char *wrapper_file_name, const char *file_base, gb_constructs &gb)
{

    if (!veri_file::Analyze(file_name, veri_file::VERILOG_2K /*v2k*/)) return 1 ;

    // Get all the top level modules
    Array *all_top_modules = veri_file::GetTopModules() ;
    // Get a handle of the first top level module, if any.
    VeriModule *mod = (all_top_modules && all_top_modules->Size()) ? (VeriModule *)all_top_modules->GetFirst() : 0 ;
    if (!mod) {
        Message::PrintLine("Cannot find a top level module") ;
        delete all_top_modules ;
        return 3 ;
    }

    char *mod_str;

    //Now copy of the top level module
    VeriMapForCopy id_map_table(POINTER_HASH) ;
    char *intf_name = Strings::save("intf_", mod->Name()) ;
    VeriModuleItem *intf_mod_ = mod->CopyWithName(intf_name, id_map_table, 1 /* add copied module to library containing 'mod'*/) ;
    VeriModule *intf_mod = (VeriModule *)intf_mod_;
    char *top_name = Strings::save("top_", mod->Name()) ;
    VeriModuleItem *top_mod_ = intf_mod->CopyWithName(top_name, id_map_table, 1 /* add copied module to library containing 'mod'*/) ;
    VeriModule *top_mod = (VeriModule *)top_mod_;
    delete all_top_modules ;

    // Get the module item list of module.
    Array *items = mod->GetModuleItems() ;
    VeriModuleItem *module_item;
    unsigned i;
    FOREACH_ARRAY_ITEM(items, i, module_item)
    {
        if (!module_item)
            continue;
        if(module_item->IsInstantiation()) 
        {
        	std::string mod_name = module_item->GetModuleName();
            std::string no_param_name;
            // reducing a correctly named parametrized module MyModule(par1=99) to MyModule
            // discuss with thierry !
            for (auto k : mod_name)
                if ('(' == k)
                    break;
                else
                    no_param_name.push_back(k);

            VeriIdDef *id ;
        	unsigned m ;
        	Array *insts = module_item->GetInstances();
        	FOREACH_ARRAY_ITEM(insts, m, id) 
            {
                bool is_gb_cons;
                std::map<std::string, int> m_items;
        	    const char *inst_name = id->InstName() ;
                for (const auto& element : gb.gb_mods) {
                    std::string str = element.first;
                    if (str == no_param_name) {
                        m_items = element.second;
                        is_gb_cons = true;
                        break;
                    } else {
                        is_gb_cons = false;
                    }
                }
        	    if (is_gb_cons) 
                {
                    bool imod = isimod(no_param_name);
                    std::vector<std::string> prefs;
                    std::unordered_map<std::string, std::vector<std::string>> del_inst;
                    std::map<std::string, std::string> conn_info ;
                    std::pair<std::string, std::map<std::string, std::string>> inst_conns;
        	        if (id) Message::Info(id->Linefile(),"here '", inst_name, "' is the name of an instance") ;
                    VeriIdDef *formal ;
                    VeriIdDef *actual_id ;
                    VeriExpression *actual ;
                    const char *formal_name ;
                    std::string actual_name ;
        	        VeriExpression *expr ;
        	        unsigned k ;
        	        Array *port_conn_arr = id->GetPortConnects() ;
        	        FOREACH_ARRAY_ITEM(port_conn_arr, k, expr) {
                        formal_name = expr->NamedFormal() ;
                        formal = module_item->GetPort(formal_name) ;
                        actual = expr->GetConnection() ;
                        if (actual->GetClassId() == ID_VERICONCAT) {
                            prefs.push_back(formal_name);
                            Array *expr_arr = actual->GetExpressions();
                            unsigned i;
                            VeriExpression *pexpr;
                            FOREACH_ARRAY_ITEM(expr_arr, i, pexpr)
                            {
                                actual_id = (pexpr) ? pexpr->FullId() : 0 ;
                                actual_name = actual_id->Name();

                                if(actual_id->Dir() == VERI_INPUT) {
                                    gb.del_ports.insert(actual_name);
                                } else if(actual_id->Dir() == VERI_OUTPUT) {
                                    gb.del_ports.insert(actual_name);
                                } else {
                                	if (imod) {
                                		// check in gb mods for direction
                                        for (const auto& pair : m_items) {
                                            if(pair.second) {
                                                conn_info.insert(std::make_pair(actual_name, formal_name));
                                                //mod->AddPort(actual_name /* port to be added*/, VERI_INPUT /* direction*/, 0 /* data type */) ;
                                            }
                                        }
                                		} else {
                                		// check in gb mods for direction
                                        for (const auto& pair : m_items) {
                                            if(!pair.second) {
                                                conn_info.insert(std::make_pair(actual_name, formal_name));
                                                //mod->AddPort(actual_name /* port to be added*/, VERI_OUTPUT /* direction*/, 0 /* data type */) ;
                                                }
                                        }
                                		}
                                	}
    


                            }
                        } else if (actual->GetClassId() == ID_VERIINDEXEDID) {
                            VeriIndexedId *indexed_id = static_cast<VeriIndexedId*>(actual) ;
                            unsigned port_dir = indexed_id->PortExpressionDir() ;
                            unsigned port_size = indexed_id->FindSize();
                            const char *port_name = indexed_id->GetName() ; // Get port name
                            Message::Info(indexed_id->Linefile(),"here '", port_name, "' is an indexed id in a port declaration") ;
                        }  
                        else {
                            actual_id = (actual) ? actual->FullId() : 0 ;
                            actual_name = actual_id->Name();
                            prefs.push_back(formal_name);
                            if(actual_id->Dir() == VERI_INPUT) {
                                gb.intf_ios.push_back(std::make_pair(actual_name, VERI_INPUT));
                                gb.del_ports.insert(actual_name);
                            } else if(actual_id->Dir() == VERI_OUTPUT) {
                                gb.intf_ios.push_back(std::make_pair(actual_name, VERI_OUTPUT));
                                gb.del_ports.insert(actual_name);
                            } else if(actual_id->Dir() == VERI_INOUT) {
                                gb.intf_ios.push_back(std::make_pair(actual_name, VERI_INOUT));
                                gb.del_ports.insert(actual_name);
                            } else {
                            	if (imod) {
                            		// check in gb mods for direction
                                    for (const auto& pair : m_items) {
                                        if (strcmp((pair.first).c_str(), formal_name) == 0) {
                                            if(pair.second == OUT_DIR) {
                                                gb.mod_ios.push_back(std::make_pair(actual_name, VERI_INPUT));
                                                gb.intf_ios.push_back(std::make_pair(actual_name, VERI_OUTPUT));
                                            }
                                        }
                                    }
                            		} else {
                            		// check in gb mods for direction
                                    for (const auto& pair : m_items) {
                                        if (strcmp((pair.first).c_str(), formal_name) == 0) {
                                            if(pair.second == IN_DIR) {
                                                gb.mod_ios.push_back(std::make_pair(actual_name, VERI_OUTPUT));
                                                gb.intf_ios.push_back(std::make_pair(actual_name, VERI_INPUT));
                                            }
                                        }
                                    }
                            		}
                            	}
                            }
        	        }
                     
                    for (const auto& prf : prefs) {
                        mod->RemovePortRef(inst_name /* instance name */, prf.c_str() /* formal port name */) ;
                    }
                    gb.gb_insts.push_back(inst_name);
    	        } else {
                    gb.normal_insts.push_back(inst_name);
                }
    	    }
        }
    }

    for (const auto& gb_inst : gb.gb_insts) {
        mod->RemoveInstance(gb_inst.c_str() /* instance to be removed*/) ;
    }

    std::vector<std::string> stringsToRemove;

    // Find strings with multiple occurrences in gb.intf_ios
    for (const auto& pair : gb.intf_ios) {
        const std::string& str = pair.first;
        auto it = std::find_if(stringsToRemove.begin(), stringsToRemove.end(),
                               [&str](const std::string& s) { return s == str; });
        if (it != stringsToRemove.end()) {
            // String is already marked for removal, skip to the next pair
            continue;
        }

        auto count = std::count_if(gb.intf_ios.begin(), gb.intf_ios.end(),
                                   [&str](const std::pair<std::string, int>& p) {
                                       return p.first == str;
                                   });
        if (count > 1) {
            stringsToRemove.push_back(str);
        }
    }

    // Remove pairs from gb.intf_ios and gb.mod_ios
    gb.intf_ios.erase(std::remove_if(gb.intf_ios.begin(), gb.intf_ios.end(),
                                     [&stringsToRemove](const std::pair<std::string, int>& p) {
                                         return std::find(stringsToRemove.begin(), stringsToRemove.end(),
                                                          p.first) != stringsToRemove.end();
                                     }),
                      gb.intf_ios.end());

    gb.mod_ios.erase(std::remove_if(gb.mod_ios.begin(), gb.mod_ios.end(),
                                    [&stringsToRemove](const std::pair<std::string, int>& p) {
                                        return std::find(stringsToRemove.begin(), stringsToRemove.end(),
                                                         p.first) != stringsToRemove.end();
                                    }),
                     gb.mod_ios.end());

    for (const auto& pair : gb.mod_ios) {
        mod->AddPort((pair.first).c_str() /* port to be added*/, pair.second /* direction*/, 0 /* data type */) ;
    }

    for (const auto& dp : gb.del_ports) {
        mod->RemovePort(dp.c_str());
        mod->RemoveSignal(dp.c_str() /* signal to be removed */) ;
    }

    for (const auto& rm_sig : stringsToRemove) {
        mod->RemoveSignal(rm_sig.c_str() /* signal to be removed */) ;
        top_mod->RemoveSignal(rm_sig.c_str() /* signal to be removed */) ;
    }

    // to check connections of extra ports in wrapper
    //mod->AddPort("D" /* port to be added*/, VERI_OUTPUT /* direction*/, 0 /* data type */) ;
    
    mod_str = mod->GetPrettyPrintedString();

//
    /////////////////////////////////////////////////////////////////////////
    
    for (const auto& pair : gb.intf_ios) {
        intf_mod->AddPort((pair.first).c_str() /* port to be added*/, pair.second /* direction*/, 0 /* data type */) ;
    }

    for (const auto& del_inst : gb.normal_insts) {
        intf_mod->RemoveInstance(del_inst.c_str() /* instance to be removed*/) ;
    }

    for (const auto& del_inst : gb.normal_insts) {
        top_mod->RemoveInstance(del_inst.c_str() /* instance to be removed*/) ;
    }

    for (const auto& del_inst : gb.gb_insts) {
        top_mod->RemoveInstance(del_inst.c_str() /* instance to be removed*/) ;
    }

    VeriModuleInstantiation *intf_inst = top_mod->AddInstance("intf_inst", intf_name) ;
    for (const auto& pair : gb.intf_ios) {
        top_mod->AddPortRef("intf_inst" /* instance name */, (pair.first).c_str() /* formal port name */, new VeriIdRef(Strings::save((pair.first).c_str())) /* actual */) ;
    }

    VeriModuleInstantiation *mod_inst = top_mod->AddInstance("mod_inst", mod->Name()) ;
    for (const auto& pair : gb.mod_ios) {
        top_mod->AddPortRef("mod_inst" /* instance name */, (pair.first).c_str() /* formal port name */, new VeriIdRef(Strings::save((pair.first).c_str())) /* actual */) ;
    }

    char *intf_mod_str = intf_mod->GetPrettyPrintedString();
    char *top_mod_str = top_mod->GetPrettyPrintedString();

    //call function to generate wrapper

    /* /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\ *
     *                Write modified source file to a file                *
     * \/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ */
    Message::PrintLine("Writing the design to file ", out_file_name) ;

    std::ofstream out_file ;
    out_file.open(out_file_name) ;
    out_file << mod_str;

    /* /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\ *
     *                Write modified source file to a file                *
     * \/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ */
    //Message::PrintLine("Writing the wrapper to file ", wrapper_file_name) ;
//
    std::ofstream wrapper_file;
    wrapper_file.open(wrapper_file_name);
    wrapper_file << intf_mod_str;
    wrapper_file << top_mod_str;

    // Remove all analyzed modules
    veri_file::RemoveAllModules() ;

    return 0 ; // Status OK
}

