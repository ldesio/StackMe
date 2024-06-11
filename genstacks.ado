
capture program drop genstacks			// Alias 'genst' which exists as a separate program defined after this one

program define genstacks

*!  Stata version 9.0; stackMe version 2, updated May'23 from major re-write in June'22; again in May'04 to include post-wrapper code

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program  
										// (lines that end with "**" need to be tailored to specific stackMe commands)
									
															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'
	local optMask = " ITEmname(varname) CONtextvars(varlist) STAckid(name) UNItname(name) TOTstackname(name) " ///					**
				  + "FE(namelist) FEPrefix(string) LIMitdiag(integer -1) KEEpmisstacks NOCheck"					//					**
															// NOTE that, for this `cmd', stackid is a name not a variable			**
															// NOTE that, for this `cmd', first option is not also a prefix			**
															// and does not have a negative counterpart
															
	if (strpos("`0'","`rep'"))>0 local replace = "replace"	// 'replace' is standard stackMe option so will be there if invoked 	**
															// (parsed here to be available on return from wrapper)					**
															// (limitdiag cannot be parsed in same way so we use a global for that) **
																
	local prfxtyp = /*"var" "othr"*/"none"					// Nature of varlist prefix – var(list) or other. (`stubname' will		**
															// be referred to as `opt1', the first word of `optMask', in codeblock 
															// (0) of stackmeWrapper called just below). `opt1' is always the name 
															// of an option that holds a varname or varlist (which must be referred
															// using double-quotes). Normally the variable named in `opt1' can be 
															// updated by the prefix to a varlist. In geniimpute the prefix can 
															// itself be a varlist.
		
		
	local multicntxt = "multicntxt"							// Whether `cmd'P takes advantage of multi-context processing			**
															// (revised genstacks DOES do so; wrapper equivalent is `noMultiContxt')
*	************************
	stackmeWrapper genstacks `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line				
*	************************								// (`0' is what user typed; `prfxtyp' & `optMask' were set above)	
															// (`prfxtyp' placed for convenience; will be moved to follow optns)
															// () that happens on fifth line of stackmeCaller's codeblock 0)
																 

												
											
*  Standard stackMe options:
*  EXTradiag REPlace NEWoptions MODoptions NEWexpression MODexpression NODIAg NOCONtexts NOSTAcks  
*  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS. All of these except limitdiag are added in stackmeWrapper, codeblk(2)

												
												
										// Next code blocks are unique to genstacks caller; most stackMe cmds don't do files or labels
										// (only other cmd to mess with labels is 'gendummies – and IT does not do multi-contexts)
	
*set trace on
	
										// (2) Make labels for reshaped vars, based on first var in each battery ...
										
	local namelist = "$reshapeStubs"					// Global saved in stackmeWrapper
								
	local suffixNotNum = ""								// Accumulate list of stubs w'out numeric suffixes
	
	local varlabel = ""									// Initialize a local outside foreach loop to hold eventual label
		
	foreach stub of local namelist {					// (whether specified in syntax 2 or derived from syntax 1 varlist)
	
		foreach var of varlist `stub'*  {				// Sleight-of-hand to get first var in each battery
		
			local varname = "`var'"						// Need to save copy for use outside this loop
			
			local label : variable label `var'			// Label stub, will be extended as appropriate
			
			if "`label'"=="" continue, break			// If this var has no label, break to next stub

			local loc = strpos("`label'", "==")			// Otherwise see if the label contains the string "=="
														// (meaning it starts with the associated varname)

			if `loc'>0  {								// If it contains the varname, delete it
				local varname = substr("`label'", 1, `loc'-1)
				capture confirm variable `varname'		// See if dummies kept original varname as stubnames
				
				if _rc == 0  {							// If this stub was previously a variable ...
					local label : variable label `varname'
					local varlabel = "Stkd `label'"
					continue, break						// Break out of foreach `var' because we found a generic label
					
				}										// (from variable whose categories became dummy variables)

				else  {									// Either never labeled or was renamed during gendummies

					local varlabel : variable label `var'
														// Repeat until labels for all dummies have been appended
				} //end else
				
			} //endif 'loc'	
			
			else {											 // Not a gendummies-built battery
			
				if strpos("`label'", "`var'") > 0	{		 // If it has an embedded varname ...
					local loc = strpos("`label'", "`var'")
					local label = substr("`label'",`loc'+strlen("`var'"), .)
					local cc = (substr("`label'", 1, 1))
					mata:st_numscalar("a",ascii("`cc'")) 	 // Get MATA to tell us the ascii value of `cc'

					while (strpos("<=>?@[\/]_{|}~", "`cc'") < 1) & ("`cc'" != "") & ( (a<45 & a!=41) | a>126 )  {
					   local label = substr("`label'", 2, .) // (strpos & 41 are good; a<45 & a>126 are not)
					   local cc =(substr("`label'"),1,1) 	 // Trim chars other than "good" above from front of label
					   mata: st_numscalar("a", ascii("`cc'"))
					}										 // (the above doesnt include " " so leading spacess get trimmed)
					local varlabel = "Stkd " + strltrim("`label'")
					continue, break							 // Break out of foreach 'var' because 1st var is all we need
				}
				else  {
					local varlabel ="Stkd " + strltrim("`label'") // Otherwise use label of first var, unmodified
					continue, break
				}
			} //end else
						
		} //next `var'										// Actually, not so as will break out of loop after 1st var
		
	
		if $limitdiag != 0  noisily display "Labeling {result:`stub'}: {result:`varlabel'}"

		label var `stub' "`varlabel'"
	
	} //next `stub'											// Find next now-reshaped var needing a label
	 

pause on
pause genstacks (2)	
pause off	
		  
		  
									// (3) Drop unstacked versions of now stacked variables; construct data label
									
	if "`replace'"=="replace" {								// If  commandline contains option "replace"
		varsImpliedByStubs `namelist'						// Program can be found at end of `stackmeWrapper' adofile
		local varlist = r(keepv)

		if $limitdiag  noisily display _newline "As 'replace' was optioned, dropping original versions of now stacked variables"
*								                 12345678901234567890123456789012345678901234567890123456789012345678901234567890

		drop `varlist'										// 'varlist' is list of variables corresponding to syntax 2 stubs
	}														// (in syntax 1 for genstacks these would have identified each batery)


									

	capture confirm variable `itemname'
	if !_rc  {
		generate SMitem = "`itemname'"						// Write name of "`itemname'" variable as string into all obs for SMitem
		if $limitdiag {
			display as error  "NOTE: Option 'itemname' stores battery ID's varname '`itemname'' in var SMitem{txt}"
							  "      Alternative to 'SMstkid' for identifying battery items in each stack"
		}
	}
	else if $limitdiag  display as error "NOTE: With no 'itemname' option, battery items are identified only by 'SMstkid'{txt}"
*                                         12345678901234567890123456789012345678901234567890123456789012345678901234567890

	   		  
			  
		  
															// Construct recommended data label
	local dtalabel : data label								// dta label is still present in kept working data
	
	local stackMeLabel1stWrd = "STKD "		  				// Put flag in first word of data label of stackMe-stacked dataset 
															// (SMstkid could have been changed to itemname)

	if ("`dtalabel'"=="")  {								// If there is no existing label...
		noi display _newline "Unstacked data were not labeled. Suggested label for stacked dta is:"
		noi display "`stackMeLabel1stWrd' by stackMe's genstacks"
		global newlabel "`stackMeLabel1stWrd' by stackMe's genstacks"
	}

	else  {													// Otherwise extend existing label

		noi display _newline "Genstacks suggests a data label for the stacked data as follows:"
*                             12345678901234567890123456789012345678901234567890123456789012345678901234567890
		global newlabel = "`stackMeLabel1stWrd'`dtalabel'"
		local len = strlen("$newlabel")						// Get initial length of old label + Stackid
		if `len' > 80  {
			global newlabel = substr("$newlabel", 1, 77) + ".."
		}
		noi display "{bf:$newlabel}"						// Actual labeling follows below

	} //end else
	
										
    noi display "{bf:$newlabel}"						
	label data "$newlabel"
	noi display as error  _newline "Data label length is limited to 80 chars. Accept suggested label by typing 'q';{txt}"
	noi display as error "else paste above text into commnd window following 'label data'; edit & return" _newline
*               		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
	window stopbox note ///
	"Accept suggested label by typing 'q'; else type 'label data ' into command window followed by suggested label within double-quotes; Edit, enter/return, then type 'q' at next prompt."
	
	
	pause on	   
	   
	pause Type q to accept above label; else edit label as instructed, then type q
*   12345678901234567890123456789012345678901234567890123456789012345678901234567890

	pause off
	   
	   
	   
	   
	   
	local report = "Not saved."								  // Default is to save nothing
	   
	noi display as error _newline "Save stacked data under a new name to avoid overwriting the unstacked file?{txt}"															
	capture window stopbox rusure "Save stacked data under a new name to avoid over-writing the unstacked file?"
*              		               12345678901234567890123456789012345678901234567890123456789012345678901234567890

	if _rc==0  {											  // $filename was saved in opening lines of stackmeWrapper
		local len = strlen("$filename")						  // Length of full path to filename + filename
		local loc = strrpos("$filename","/")				  // Location of final "/" in that path, preceeding filename
		local newfile ="STKD " +substr("$filename",`loc'+1,.) // Local copy not emptied by fsave when user cancels
		global newfile = "`newfile'"						  // Need global for call on fsave, emptied on cancel

	   	capture window fsave newfile "File in which to save stacked data" "Stata Data (*.dta)"
	   	if _rc==0  {
			capture save "$newfile"
			if _rc!=0  {
				noi display as error _newline "Overwrite existing file?{txt}" // Save dataset to avoid overwriting
				capture window stopbox rusure "Overwrite existing file?"
				if _rc==0  {
					noi display "replacing as " _continue
					local report = ""
					save "$newfile", replace
				}
			} //endif _rc==0
			else local report = "File $newfile saved."
		} //endif 											  // With default report "Not saved"
	} //endif _rc==0										  // With default report "Not saved"
	
	noisily display _newline "`report'" _continue


	global newlabel = ""									  // Empty globals used for this command	
	global newfile = ""
	global limitdiag = ""
	global reshapeStubs = ""

end //genstacks	




************************************************** program genst ********************************************


capture program drop genst

program define genst

genstacks " `0'"

end //genst

