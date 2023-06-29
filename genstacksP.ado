
capture program drop genstacksP

*!  This program makes calls on Stata's reshape command

program define genstacksP

*!	Version 2 uses the command window to build label for stacked data; unlike version 2a which uses a dialog box.

*!  Stata version 16.1 (originally 9.0); gendist version 2.0, updated Jan'22 from major re-write in June'22
*!  Search sreshape for a faster reshape command published in 2019 (possibly already incorporated into Stata 17)
*!  However, reshape is not the slow part. A faster merge command would be good!


	version 16.1											 // stackMe genstacks version 2.0, June 2022, updated 1'23, 2'23
	
	// This version of genstacks does not reshape each context separately but all contexts together. However, it does not use 
	// Stata's code for duplicating variables that are not reshaped. Instead it saves those variables and later merges them 
	// with the reshaped variables. It uses external files to do this rather than data frames, because of limitations on the 
	// type of merges that frames support.
	//   The program skips stubs that do not have numeric suffixes (e.g. RSYML1 as a supposed variable in a battery named RSYM) 
	// and culls records that (after stacking) are all missing due to stacked variables being all missing for certain 
	// contexts.
	//   Trial versions used Stata's version # to evaluate use of frame technology. It used a call on Mata to get the version #,
	// thus: mata: st_numscalar("temp", statasetversion()), returns versn # in scalar 'temp'.

	
	
	syntax anything [aw fw pw/], [ CONtextvars(varlist) UNItname(varname) STAckid(name) ITEmname(varlist) TOTstackname(name)] ///
								 [ REPlace NODiag KEEpmisstacks FE(namelist) FEPrefix(string) LIMitdiag(string) NOCheck ] ///
								 [ ctxvar(varname) nc(integer 0) c(integer 0) nvarlst(integer 1) ] 


	if `limitdiag'==0  local nowarnings = "nowarnings" 		// `nodiagnostics' was `nowarnings' in version 1
		

	global noisily = ""

	
	
	
	
	local dtalabel : data label								// Retrieve any existing data label
	
	gettoken istword rest : dtalabel
	gettoken pre post_   : istword, parse("_")
	if "`pre'" == "stackMe"  {								// If these data already had a "Stkd" prefix for their datalabel
		display as error 			  "WARNING: Dataset label suggests this dataset was already stacked. Continue?"
		capture window stopbox rusure "WARNING: Dataset label suggests this dataset was already stacked. Continue?"
		if _rc==0  {										// NEED TO DESIGN DATASET LABEL FOR DOUBLY-STACKED DATASET				***
			display as error "stackMe indicator trimmed from start of dataset label"
			local dtalabel = strltrim("`rest'")
			label data "`dtalabel'"
		}
		else {
			display as error "Exiting genstacks"
			exit
		}
	}		

	
	
	
	
									// Preprocess options for possible errors or requiring other manipulation . . .
									
	if "`unitname'"!=""  {
		capture confirm variable `unitname'
		if _rc  {
			display as error "Option {opt uni:tname} names {it:`unitname'}; not a valid varname"
			window stopbox stop "Option 'unitname' names `unitname'; not a valid varname"
		}
	}
								
	local list = ""							
	if strlen("`fe'") > 0  {
		foreach fevar of local fe  {
			if (strpos("`namelist'","`fevar'")==0) & ("`fevar'"!="_all")  {
				local list = "`list' `var'"
			}
		} //next 'fevar'
	} //endif

	if "`list'"!=""  {
		display as error	"Not in namelist: optioned fe var(s) `list'"
	`	window stopbox stop "Optioned fe variables not among vars to be processed (see list)"
	}
	

	if strlen("`replace'")>0  local r = 1
	else local r = 0
	
	
	if "`nodiagnostics'"!="" | "`nowarnings'"!=""  {
		local w = 0
		local displ = "quietly"
	}
	
	else  {
		
		local w = 1
		local displ = "noisily"
	}	
	
	
	tempvar _genstacks
	quietly gen `_genstacks' = .							// Place "marker" for end of dataset before first newvar	

	set more off
	
	noisily display as text in smcl
	noisily display ".." _continue							// First "busy"dots
	

	
	
	
	
	
	
									// Cycle thru all varlists in multi-varlist set (if there is such a set)
	
	local lststub = ""								 		// Flags registering nature of varlist
	local difstub = ""										// All stubs are the same for each battery if empty
	local batlen = 0										// Length of previous battery (n of battery items)
	local namelist = ""										// Will be progressively filled if found from varlist(s)
	local nosfx = 0											// By default assume list of stubs (w'out suffixes)
									
	forvalues nvl = 1/`nvarlst'  {					 		// Syntax 1 stubs must be built from (successive) varlist(s)
			
	   gettoken prepipes postpipes:anything,parse("||")		//`postpipes' will now start with "||" or be empty at cmd's end
	
	   local istword = strrtrim(word("`prepipes'", 1))		// Examine first word in varlist, trimming any final blanks
	   
	   local lstchar = substr("`istword'",-1,1)				// Extract final character from 1st word
	   
	   if real("`lstchar'")!=.	{							// If it is numeric
		
		  unab varlist : `prepipes'						 	// Syntax 1 stub(s) start out as varlist(s)
		
		  local nvars : list sizeof varlist
		
		  if `batlen'>0 & `batlen'!=`nvars' & "`nocheck'"!=""   { 
		     if  `limitdiag'!=0  {
		        display as error 	  "WARNING: Batteries have different # of vars across battery stubnames. Continue?"
		        window stopbox rusure "WARNING: Batteries have different # of vars across battery stubnames. Continue?"
															// Stata will issue a -break- if answer is "no"
		     }
		  }
		  
		  local batlen = `nvars'

		  foreach var of varlist `varlist'  {				// Extract stub from each var & ensure all are same

		    if real(substr("`var'",-2,2))==.  {				// If numeric suffix is not 2 chars long
			   local stub = substr("`var'",1,strlen("`var'")-1) // Then it must be a 1-char suffix
			}
			else local stub=substr("`var'",1,strlen("`var'")-2)	// Otherwise it is 2 chars long
			if ("`lststub'"!="" & "`lststub'"!="`stub'") {	// If there is a previous stub & it is not same
			   local difstub = "difstub"					// Then flag it as being different
			}
			local lststub = "`stub'"						// Store this stub in `lststub' for next test
		  
		    if "`difstub'"!=""  {
			   display as error "Varlist must have same stubname for all variables in a battery. Missing '||'?"
							  // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			   window stopbox stop "Varlist must have same stubname for all variables in a battery. Missing '||'?"
		    }
					
		  } //next`var'  
		  
		  local namelist = "`namelist' `stub'"				// Add stubname to list of stubs
		  
		  local lststub = ""								// And empty `lststub' for check of next battery

	   } //endif`nfs'										// End of varlist
		
	   else  {												// Stub does not have numeric suffix
		
		  local namelist = "`prepipes'"						// So entire namelist is in 1st `prepipes'
		  local nosfx = 1									// Set nosuffix flag for later use
		   
	   }
	   
	   if "`namelist'"=="`varlist'" & substr("`postpipes'",1,2)=="||"  { 		// If `varlist' & pipes

		   display as error "List of stubnames should not be followed by '||'"
		   window stopbox stop "List of stubnames should not be followed by '||'"
	   }
		
	   if substr("`postpipes'",1,2)=="||"  local anything = substr("`postpipes'", 3, .)
															// Put next varlist into `anything'

	} //next `nvl' (varlist) 
	  
	  

	  
	  
		
									// Ensure no stubs (derived from either syntax) are names of actual variables

	local list = ""
	foreach stub of local namelist  {	
		capture confirm variable `stub'
		if _rc == 0  {										// If this stub is an existing variable
			local list = "`list' `stub'"					// Save it in extendable list
		}
	} //next `stub'

	if "`list'"!=""  {
		display as error "Some supposed stubnames(s) are existing variable(s); see displayed list"
		window stopbox stop "Some supposed stubnames(s) are existing variable(s): `list'"
	}


	
	
*	if !`nosfx'  {											// If not multi-varlist



			
								// Diagnose batteries with different numbers of suffixes (indexes) . . .

		local previndexlist = ""							// This codeblock may be redundant 'cos reshape checks ***
		local diffindexlist = 0
		
		local varlist = ""		
		
	
		foreach stub of local namelist {					
		
		  local indexlist = ""
		
		  foreach var of varlist `stub'*  {					// if what comes after the stub is not numeric, skip										
															// (useful if diffrnt battries share part of the stub,
			local strindex = substr("`var'", strlen("`stub'")+1, .) //  				  e.g. rsym and rsyml)
					
			if (real("`strindex'")==.) continue, break  	// Continue with next stub if this one's suffix not numeric	

			local varlist = "`varlist' `var'"
			local indexlist = "`indexlist' `strindex'"

		  } //next var
		
		  if "`previndexlist'" != ""  {					// If this is 2nd or subsequent battery
			if indexnot("`indexlist'","`previndexlist'")>0  local diffindexlist = 1
			if indexnot("`previndexlist'","`indexlist'")>0  local diffindexlist = 1
		  }
		
		  local previndexlist = "`indexlist'"

		} //next stub
	
		if `diffindexlist'>0 & `w' & "`nockeck'"!=""  {

		   display as error		 "WARNING: Batteries have different # of vars across battery stubnames. Continue?"
		   window stopbox rusure "WARNING: Batteries have different # of vars across battery stubnames. Continue?"
		   
		}												// stopbox will issue a --break-- if answered "no"
	
*	} //endif !`nosfx'
	
	
	noisily display "." _continue
	local 0 = "`varlist'`multivarlst'"					// Place in `0' whichever varlist is non-emptu
	syntax varlist										// Check that eventual varlist has existing variables
														// (Stata will issue an error message otherwise)
	

	
	
	
								// Make labels for vars to be reshaped, based on first var in each battery ...

	local suffixNotNum = ""								// Accumulate list of stubs w'out numeric suffixes
		
	foreach stub of local namelist {					// (whether specified in syntax 2 or derived from syntax 1 varlist)
		
		local `stub'n = ""								// Re-create `stub'n variable

		foreach var of varlist `stub'*  {				// Sleight-of-hand to get first var in each battery
			
			local varlabel = "Stkd "					// Label stub, extended as appropriate

			local strindex = substr("`var'",strlen("`stub'")+1,.)
		
			capture confirm number `strindex'
			if _rc > 0	{								// If suffix is not numeric stub may be part of longer varname
				continue								// Continue thru varlist looking for numeric suffixes
			}
			else  {										// Found a numeric suffix
				local `stub'n = "yes"					// Set flag that this stub has corresponding variable(s)
			}
						
			local label : variable label `var' 			// See if variables were created by gendummies
														// (in which case original varname will preceed label
			local loc = strpos("`label'", "==")			//  with "==" following the varname)
			
			if `loc'>0  {
				local varname = substr("`label'", 1, `loc'-1)
				capture confirm variable `varname'		// See if dummies kept original varname as stubnames
				
				if _rc == 0  {							// If this stub was previously a variable ...
					local label : variable label `varname'
					local varlabel = "Stkd " + strltrim("`label'")
					continue, break						// Break out of foreach `var' because we found a generic label
				}										// (from variable whose categories became dummy variables)

				else  {									// Either never labeled or was renamed during gendummies

					local varlabel = "`varlabel'`label'  "
														// Repeat until labels for all dummies have been appended
				} //end else
				
			} //endif 'loc'	
			
			else {										// Not a gendummies-built battery
			
				if strpos("`label'", "`var'") > 0	{	// If it has an embedded varname ...
					local loc = strpos("`label'", "`var'")
					local label = substr("`label'", `loc'+strlen("`var'"), .)
					local c = (substr("`label'", 1, 1))
					mata:st_numscalar("a",ascii("`c'")) // Get MATA to tell us the ascii value of `c'
					while (strpos("<=>?@[\/]_{|}~", "`c'") < 1) & ("`c'" != "") & ( (a<45 & a!=41) | a>126 )  {
					   local label = substr("`label'", 2, .) // (strpos & 41 are good; a<45 & a>126 are not)
					   local c =(substr("`label'"),1,1) // Trim chars other than "good" above from front of label
					   mata: st_numscalar("a", ascii("`c'"))
					}									// (the above doesnt include " " so leading spacess get trimmed)
					local varlabel = "`varlabel'`label'  "
					continue, break						// Break out of foreach 'var' because we built a generic label
				}
				else  {
					local varlabel ="`varlabel'`label'"	// Otherwise use label of first var, unmodified
					continue, break
				}
			} //end else
						
		  } //next `var'
		
		  local `stub'label = "`varlabel'"
		  if "`stub'n" == ""  local suffixNotNum = "`suffixNotNum'`stub' "
		
		} //next `stub'
	
		if "`suffixNotNum'" != ""  {
		  display as error "Expected numeric suffix(s) not found for `suffixNotNum'"
		  window stopbox stop "Expected numeric suffix(s) not found for displayed stubs"
		}
		
	
	
	
	
								// Get respondent ID, save frame or tempfile of variables constant across stacks . . .
														
/*
		mata: st_numscalar("STATAVERSION",statasetversion()) // Commented out because slower than using tempfile

		if STATAVERSION>1600  frame put _all, into(unstacked)
		else  {
			tempfile unstacked								// faster than the frames code
			quietly save `unstacked'						// Save original dataset to merge with reshaped variables
*		}

		if `w' noisily display " "
		else noisily display "." _continue
	
	
	
	
	
								// Reshape as optioned . . .
														
		quietly keep `SMunit' `varlist'						// Keep just the variables to be reshaped (and identifiers)
*/								// End of wrapper codeblocks
	
	
	
	
*				************
		`displ' reshape long `namelist', i(SMunit) j(SMstkid)	
*				************								// Values of 'stackMe_stkid' are supplied by 'reshape'
														
	
	
		egen SMtotstacks = max(SMstkid), by(`SMunit')
		order SMtotstacks, after(SMstkid)
	

/*		if STATAVERSION>1600  {								// Commented out because slower than merging a tempfile
			quietly frlink m:1 `SMunit' _ctx_temp, frame(`unstacked')
			quietly frget _all, from(`unstacked')
			frame drop unstacked
		}													// Merge now done in wrapper
		else  {												// Faster than the frames code
		   `displ' merge m:1 `SMunit' using `unstacked', nogen nolabel
			erase `unstacked'
*		}
		
*/		if !`w' noisily display "." _continue
		
		
	
	
									// Flag and optionally drop stacks where all vars are missing . . .
								
	local totstubs = wordcount("`namelist'")
	tempvar totmiss
	egen `totmiss' = rowmiss(`namelist')

	if `w' noisily display _newline "Flagging contexts where all reshaped variables are missing, to delete by default"
	tempvar dropable
	gen `dropable' = 0
	quietly replace `dropable' = 1 if `totmiss'==`totstubs'
	
	if ("`keepmisstacks'"=="")  `displ' drop if `dropable'
	
	if !`w' noisily display "." _continue

*	if `r'  drop `varlist'								// Dropping original battery member vars was optioned
														// (commented out because Stata's reshape itself deletes them)
		
	

	
	

									// Label reshaped vars using labels created before reshaping ...
								
	foreach stub of local namelist {

		local label = "``stub'label'"

		if `w' noisily display "Labeling {result:`stub'}: {result:`label'}"

		label var `stub' "`label'"
	
	}
	
	

	

									// Process fixed effects if optioned . . .

	if ("`fe'"!="") {
		if ("`feprefix'"!="") {
			local feprefix = "`feprefix'"
		}
		else {
			local feprefix = "fe_"
		}
		if `w' {				   // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			noisily display _newline "Applying fixed-effects treatment to fe-vars (subtracting unit-level means)"
		} //endif `w'

		
		if ("`fe'"=="_all")  local fe = "`namelist'"
		
		local felist = ""										// Will hold list of fe vars
		foreach fevar of local fe {
			tempvar t
			if `w' display "`feprefix'`fevar' " _continue
			capture drop `feprefix'`fevar'
			quietly bysort `SMunit': egen `t' = mean(`fevar')	// Need to weight this calculation								***
			`displ' gen `feprefix'`fevar' = `fevar' - `t'
			drop `t'
			local felist = "`felist' `feprefix'`fevar'"
		}
		
		display _newline
			
	} //endif ("`fe...")

	if !`w' noisily display "." _continue
	
	
	
		  
		  
									// Rename generated variables if optioned . . .
		
	if ("`unitname'" != "")  {
		display as error "'SMunit', the default unitname, is used by other stackMe commands. Change anyway?"
*                          12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "SMunit, the default unitname, is used by other stackMe commands. Change it anyway?"
		if _rc==0  rename SMunit `unitname'		 					// This names a new variable; itemname names an existing variable
		else  {
			noisily display "'SMunit' changed to `unitname'"
			window stopbox note "'SMunit' changed to `unitname'"
		}
	}
	else local unitname "SMunit"

	if ("`stackid'" != "")  {
		display as error "'SMstkid', the default stackid, is used by other stackMe commands. Change anyway?"
*                              12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "SMstkid, the default stackid name, is used by other stackMe commands. Change it anyway?"
		if _rc==0 rename SMstkid `stackid'		 					// This names a new variable; itemname names an existing variable
		else  {
			noisily display "'SMstkid' changed to `stackid'"
			window stopbox note "'SMstkid' changed to `stackid'"
		}
	}
	else local stackid "SMstkid"
	
	if "`totstackname'" != ""  {
		display as error "'SMtotstk', default totstkname, is used by other stackMe commands. Change anyway?"
*                          12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "SMtotstk, the default totstack name, is used by other stackMe commands. Change it anyway?"
		if _rc==0 rename SMtotstk = `totstackname'
		else  window stopbox note "'SMtotstk' changed to `totstackname'"
	}
	else local totstackname "SMtotstackname"
	
	

	if !`w' noisily display "." _newline					// No 'continue' for final busy dot
	


	
		  
		  
									// Construct recommended data label

	local stackMeLabel = "stackMe"		  		  			// Default name for stack id variable 

	capture confirm variable `itemname'
	if !_rc  local stackMeLabel = "stackMe_`itemname'" 		// Add _item to stackMe label, if provided
	else  window stopbox note "Lacking an option 'itemname', battery items are identified by var `stackid'"

	local dtalabel : data label 							// dta label is still present in kept working data

	if (strlen("`dtalabel'") == 0)  {						// If there is no existing label...
		noi display _newline "Unstacked data were not labeled. Suggested label for stacked dta is:"
*                             12345678901234567890123456789012345678901234567890123456789012345678901234567890
		noi display "`stackMeLabel'"
		global dtalabel "`stackMeLabel'"
	}

	else  {													// Extend existing label

		noi display _newline "Genstacks suggests a data label for the stacked data as follows:"
*                             12345678901234567890123456789012345678901234567890123456789012345678901234567890
*				  label data "stackMe_RLRSP: UK 1994-2001 John Curtice (EV); 2005 Carla Xena; TEV harminiztn by MNF"
		local newlabel = "`stackMeLabel': `dtalabel'"
		local len = strlen("`newlabel'")					  // Get initial length of old label + Stackid
		if `len' > 80  {
			local newlabel = substr("`newlabel'", 1, 78) + ".."
		}
		noi display "{bf:`newlabel'}"
		global dtalabel "`newlabel'"

	} //end else
	

	
	
	
end //genstacksP




/*
	local dtalabel : data label 	
	display "`dtalabel'"
*/	

