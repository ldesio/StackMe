															
global errloc "genstacks0"									// Global that keeps track of execution location for benefit of 'errexit'

********
capture {													// Open capture braces mark start ot code where errors will be captured
********	


	syntax anything [aw fw pw/], [ USErcontxts(varlist) NOContexts STAckid(name) NOStacks ITEmname(varlist) NOCheck ] ///
								 [ REPlace NODiag KEEpmisstacks FE(namelist) FEPrefix(string) LIMitdiag(integer -1) ] ///
								 [ CTXvar(varname) ORIgdta(string) WTExplst nc(integer 0) c(integer 0) NVArlst(integer 1) *] 

								 
		if `limitdiag' == -1  local limitdiag = .			// If unlimited make that a very large number

		local multivarlst = "`anything'"					// Varlist transmitted on call to this cmd

		local frstwrd = word("`multivarlst'",1)				//`multivarlst' from codeblk (0)
															// (reconstruction in codeblk 1.1 was skipped for genstacks)
		local test = real(substr("`frstwrd'",-1,1))			// See if final char of first word is numeric suffix
		local isStub = `test'==.							//`isStub' is true if result of conversion is missing

		if `isStub'  {										// If user named a stub, need list of implied vars to keep
															//  in working data
			local reshapeStubs = "`multivarlst'"			// Stata's reshape expects a list of stubs
			
			local len = strpos("`reshapeStubs'","||")
			if `len'>1  {									// If final 2 chars are "||"
				local reshapeStubs = substr("`reshapeStubs'",1,`len'-1)
			}												// Strip off final "||"
			
															// (which is what should be held in 'multivarlst')
			local nstubs = wordcount("`reshapeStubs'")		// Check that no stubnames already exist as variables
		
			local errlist = ""								// This local will store stubnames that already name a variable
		
			forvalues i = 1/`nstubs'  {
				local var = word("`reshapeStubs'",`i')
				capture confirm variable `var'
				if _rc==0  {									// Error if var already exists
					local errlist = "`errlist' `var'"
				}
			} //next `i'
		
			if "`errlist'"!=""  {
				display as error ///
					"Variable(s) already exist with stubname(s): `errlist';" _newline "drop them from stacked dataset?{txt}"
*               		  	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				if wordcount("`errlist'")>1 local msg = "drop these from stacked dataset?"
				else local msg = "drop this from stacked dataset?"
				window stopbox rusure "Variable(s) already exist with stubname(s) `errlist'; `msg'"
				if _rc errexit "Will exit on 'ok'"
				foreach `var' of local errlist  {
					quietly drop `var'
				} //next 'var'
				noisily display "Dropping offending variable(s), execution continues..."
			}
				

*			******************
			varsImpliedByStubs `reshapeStubs'				// Call on appended program
*			******************

			local impliedVars = r(keepv)					// Implied by the stubs actually specified by user	

			if strpos("`impliedvars'",".")>0  {
				errexit "Could not determine vars implied by seeming stubs"
			}

		} //endif `isStub'									// Eliminate any missing variable indicators from `keepv'


		
		else  {												// Otherwise `frstwrd' is a varname with numeric suffix
															// (suggesting that other items in `keep' are also varnames)
			 local keepv = "`multivarlst'"					// (command reshape will diagnose an error if not so)
															// `multivarlst' unchanged since codeblk (0)
*			 ******************
			 stubsImpliedByVars `multivarlst'				// Program (appended) generates list of stubnames
*			 ******************
				
			 local stublist = r(stubs)						// (one stubname per varlist in genstacks syntax 1)
*			
			 ******************
			 varsImpliedByStubs `stublist'					// See if both varlists have same vars (in any order)
			 ******************
			
			 local impliedVars = r(keepv)					// 'Implied' by the variables actually specified by user

			 local same : list impliedVars === keepv		// returns 1 in 'same' if 'implied' & 'keep' have same contents 
*		
			 if ! `same'  {
				
				display as error "Variables in dataset dont match vars implied by varlist(s). Use existing vars?{txt}"
*               		  		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				local msg = "Variables in dataset are not an exact match for vars implied by varlist(s) – "
				capture window stopbox rusure ///
								"`msg'maybe some contexts have fewer variables; use existing vars?"
				if _rc   {									// Exit with error if user says "no" 
					errexit "`Absent permission to use existing vars"
				}

				noi display "Execution continues ..."

				if strpos("`stublist'",".")  local stublist = subinstr("`stublist'", ".", "", .) // Strip missng indicatrs & go on
															// Eliminate any missing variable indicators from `stublist'
				local reshapeStubs = "`stublist'"			// Where stubs were stored if user listed them, before 'else', above   +

			  } //endif !`same'	

		} //endelse
		
		
										// Here check on options that are problematic on 'genstacks' commands
										
		if "`usercontxts'"!="" | "`nocontexts'"!=""  {
			errexit "In V2, contextvars are set by {help SMutilities} and cannot be overriden in genstacks"
*					 12345678901234567890123456789012345678901234567890123456789012345678901234567890abcdefg
		}
		
		if "`stackid'"!="" | "`nostacks'"!=""  {
			display as err "In Version 2, the stack ID variable is named SMstkid and is not user-optioned"
*						 	12345678901234567890123456789012345678901234567890123456789012345678901234567890
			window stopbox rusure "In Version 2, the stack ID variable is named SMstkid and is not user-optioned; continue?"
			if _rc  errexit "Lacking permission to continue"
		}	
		
		if "`itemname'"!=""  {								// In genstacks any 'itemname' option names var to be kept, below
			capture confirm variable `itemname'				// (it provides a link from each stack to other battery items)
			if _rc  {
				errexit "Option `itemname' does not name an existing variable" // 'errexit' limited to 60 chars
*						12345678901234567890123456789012345678901234567890123456789012345678901234567890	
			}												// 'itemname' will override SMitemname dataset characteristic
			else {											// (created by genstacks)
				if `limitdiag' noisily display "NOTE: optioned itemname will override dataset characteristic set by 'genstacks'"
*               		  		                12345678901234567890123456789012345678901234567890123456789012345678901234567890
			}
		}													// Vars in 'varsImpliedByStubs' need to be kept in working data
															// (no SM.. variables in unstacked data)
															
		local impliedvars = "`impliedVars' `itemname'"	// (genstacks does need SMitem, provided in wrapper codeblk (6)										
														    // Most codeblcks from here on will end with a list of vars to keep

															
											
					
											
pause (0.4)		
	
										// For genstacks, additional vars are generally needed beyond those in `multivarlst'
										// Also need to see if genstacks is to double-stack the data or just singly stack.
										// Either way appropriate variables need to be created and flagged for keeping
															
		
		if "`nostacks'"!="" {
			display as error "'nostacks' cannot be optioned with command genstacks. Ignore and continue?{txt}"
			capture window stopbox rusure "'nostacks' cannot be optioned with command genstacks. Ignore and continue?"
*						 	                12345678901234567890123456789012345678901234567890123456789012345678901234567890	
			if _rc {
				errexit "'nostacks' cannot be optioned with command genstacks"
			}												//  (no need to restore full dataset since not yet messed with)
			noi display "Execution continues ..."
			local nostacks = ""
		}													// This should never happen
		
		global dblystkd = ""								// Global used in `cmd'P must be empty if not double-stacked
		local dblystkd = ""
					
		capture confirm variable SMstkid					// No SMstkid means data not yet stacked
		
		if _rc ==0  {									
			local stackid = "SMstkid"  						// Return code of 0 indicates that the variable exists
			if `limitdiag'  {
				local msg = "This dataset appears to be stacked (has SMstkid variable)"	
*					         12345678901234567890123456789012345678901234567890123456789012345678901234567890
				capture window stopbox rusure "genstacks will try to double-stack these data; is that what you want?{txt}"
				if _rc  {
					global exit = 2							// $exit=2 tells 'errexit' no need to restore origdta before exit
					errexit "`msg'"  						// (NO LONGER; errexit now expects 'origdta' option if restoring)		***
				}
				display as error "Execution continues..."
			} //endif
			
			local dblystkd = "dblystkd"	

		} //endif _rc==0											

		else  {												// Else there is no SMstkid variable

			capture confirm variable SMunit					// SHOULD WE ALSO CHECK FOR HANGING SMnstks?							***
			if _rc==0  {
				display as error "NOTE: Variable SMunit should not already exist in unstacked data; continue anyway?{txt}"
				capture window stopbox rusure "Variable SMunit should not already exist in unstacked data; Continue anyway?"
*						                       12345678901234567890123456789012345678901234567890123456789012345678901234567890
				if _rc!=0  {
					errexit "Variable SMunit should not already exist in unstacked data"						
				}
				foreach var in SMunit SMnstks SMmxstks SMitem SMunit  {
					capture drop `var'
				}
				noisily display "SMunit and any other 'SM' variables will be replaced as execution continues ...{txt}"
*						          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			} //endif _rc 									// Will need these vars for stacking ** ONLY IN WORKING DTA				***
			
		} //endelse
		

		
		if "`dblystkd'"!=""  {								// If data are to be double-stacked (SMstkid already exists)
											
			capture confirm variable S2stkid				// S2stkid should not already exist in unstacked data
			
			if _rc == 0  {
				display as error "Variable S2stkid should not already exist in data to be double-stackd. Continue?{txt}"
				capture window stopbox rusure "Variable S2unit should not already exist in data not double-stacked. Continue anyway?"
*						 		  12345678901234567890123456789012345678901234567890123456789012345678901234567890	
				if _rc!=0  {
					errexit "Variable S2unit should not already exist in data not double-stacked"
				}
				else  {
					foreach name in S2stkid S2nstks S2mxstks S2unit S2item {
					   capture drop `name'					// Drop these vars if they exist
					}
					noisily display "S2stkid and any other 'S2' variables will be replaced as execution continues ..."
				}
			} //endif _rc==0								// WILL NEED THESE VARS FOR STACKING  ** ONLY IN WORKING DTA			***

		} //endif 'dblystkd'
		
		
		global dblystkd = "`dblystkd'"						// Make copy in global accessible from elsewhere
		
															// Here initialize SMvars, where they will not be kept if $exit
		if "`stackid'"==""  {
			qui gen SMstkid = .								// Missing obs will be filled with values generated by reshape
			qui gen SMnstks = .								// Missing obs will be filled with values found after stacking
			qui gen SMmxstks = .
			gen SMunit = _n									// Above missing-filled vars created to avoid re-ordering
		}
		
		if "`dblystkd'"!=""  {
			qui gen S2stkid = .								// Missing obs will be filled with values generated by reshape
			qui gen S2nstks = .								// Missing obs will be filled with values found after stacking
			qui gen S2mxstks = .
			gen S2unit = _n									// Above missing-filled vars created to avoid re-ordering
			label var S2unit "Sequential ID for observations that were units of analysis in singly-stackd data"
*						      12345678901234567890123456789012345678901234567890123456789012345678901234567890
		}

		
		local impliedvars `impliedvars' SMstkid SMnstks SMmxstks SMunit // Add S2 versions if doubly-stacked
		if "`dblystkd'"!="" local impliedvars `impliedvars' S2stkid S2nstks S2mxstks S2unit
		return local impliedvars `impliedvars'
		return local reshapeStubs `reshapeStubs'			// So-called because stubs are used for reshaping in 'genstacksP'
		

	local skipcapture = "skipcapture"						// Local, if set, prevents capture code, below, from executing

	
* *************
} //end capture												// Endbrace for code in which errors are captured
* *************												// Any such error would cause execution to skip to here
															// (failing to trigger the 'skipcapture' flag two lines up)

if "`skipcapture'"==""  {									// If not empty we did not get here due to stata error
	
	if _rc  errexit, msg("Stata reports program error in $errloc") displ orig("`origdta'")
	
}

		
end genstacksO


***************************************************** END OF PROGRAM ******************************************************************
