

capture program drop stackmeWrapper

*!  This ado file contains program stackmeWrapper that 'forwards' calls on all `cmd'P programs where `cmd' names a stackMe command. 
*!  Also subprograms (what Stata calls 'program's) 'varsImpliedByStubs' and 'stubsImpliedByVars' called frm genstacks and genstacksP
*!  as well as from this wrapper program, plus several more subprograms.
*!  Version 4 replicates normal Stata syntax on every varlist of a v 4 command (nothing is remembered from previous varlists)
*!  Version 5 simplifies version 4 by limiting positioning of ifinwt expressions to 1st varlist and options to last varlist
*!  Version 6 impliments 'SMcontextvars' and the experimental movement of all preliminary 'genplace' code to the wrapper program
*!  Version 7 revives code from Version 3 that tried to identify the actual variable employed in a weight expression

 
										// For a detailed introduction to the data-preparation objectives of the stackMe package, 
										// see 'help stackme'.

program define stackmeWrapper	  		// Called by `cmd'.do (the ado file named for any user-invoked stackMe command) this ado  
										// file repeatedly calls `cmd'P (the program doing the heavy lifting for that command) where 
										// context-specific processing generally takes place. It also parses the user-supplied 
 										// stackMe command line and sets up options and varlist(s) for the call on `cmd'P. 			***

*!  Stata version 9.0; stackmeWrapper v 4, updated Apr, Aug '23 & again Apr '24 to Mar '25' by Mark from major re-write in June'22

	version 9.0							// Wrapper for stackMe version 2.0, June 2022, updated in 2023, 2024. Version 2b extracts 
										// working data (variables and observations determined by `varlist' [if][in] and options) 
										// before making (generally multiple) calls on `cmd'P', once for each context and (generally) 										
										// stack, saving processed data for each context in a separate file. This program then merges 
										// the working data back into the original dataset. Care is taken to restore the original 
										// data before terminating after any anticipated error. (Unanticipated errors can leave the
										// user confronting a working dataset consisting of a single context and stack).
										//
										// General syntax: 'cmd varlst [ifin] [wt] [ || varlst [wt] || ... || varlst [wt] ], options' 
										// Varlist syntax: '[str_] [prefixvars :] varlist [ifin][wt]'
										//    An initial string can only occur before a prefixvar(list); 'ifin' must follow the first 
										// varlist; 'options' must follow the last varlist; 'weight's can follow any varlist. These
										// variations reduce to a standard Stata command line: 'cmd varlst [ifin] [wt], options'. In 
										// such a commandline, prefixvars and their preliminary strings become additional options.
										// 
										// StackMe commands are not totally standard in their structure or data requirements, so this 
										// wrapper program has a number of codeblocks specific to particular stackMe commnds. However
										// the general structure of the wrapper is as follows ...
										//
										// 1. Parse the syntax, separate varlists from options, parse the options, extract a list 
										// of vars needed by those optns that must be included in context-specific working dta.
										// For each varlist, extract the list of vars from which outcome varnames will be constructed
										// (the list that will govern executn of 'cmd'P); extract a list of vars needed in workng dta.
										//
										// 2. Save the original datafile for later merging with new variables; drop vars and obs not
										// needed in the working data; conduct all possible preliminary checks for data adequacy; 
										// for the current 'cmd'P invoke a preliminary 'cmd'O (for 'opening') that will conduct checks
										// that call for all contexts and conduct preliminary processing specific to each 'cmd'.
										//
										// 3. For each context, preserve the working dataset and drop all contexts other than the 
										// currently active context (generally stack-within-context but context level for 'genplace');
										// invoke 'cmd'P for that context to do the heavy lifting that transforms input variables into
										// appropriately-processed and renamed outcome variables.
										//
										// 4. Save working subset in one tempfile per context; restore preserved contexts; advance to 
										// next context and repeat until all contexts have been processed; append sequence of context
										// files into one of working vars and observations; merge newly created outcome vars with 
										// original dataset; report on missing observations per context and overall; return execution
										// to original calling program where variables will be dropped or renamed as optiond.
										// 
										// 
										// Additional introductory text can be found following codeblock (0), below.
										
										//			  Lines suspected of still proving problematic are flagged in right margin      ***
										//			  Lines needing customizing to specific `cmd's are flagged in right margin    	 **
										
										
										
pause (0)										
	

										// (0)  Preliminary codeblock establishes name of latest data file used or saved by any 
										// 		stackMe command and of other globals and locals needed throughout

	local fullname = c(filename)							// Path+name of datafile most recently used or saved by any Stata cmd.
	local nameloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Position of first char following final "/" or "\" of directory path
	local pathname = substr("`fullname'",1,`nameloc')		// `pathname' ends with `c(dirsep)' ("/" or "\")
	if strpos("`fullname'", c(tmpdir)) == 0  {				// Unless c(tmpdir) is contained in dirpath (that would be a tempfile)
		global filename = substr("`fullname'",`nameloc',.)	// Update filename with latesst name saved or used (SEEMINGLY UNUSED)	***
	}														// (needed by genstacks caller as default name for newly-stckd dtafile)

	global prefixedvars = ""								// Global will hold the list of prefixed var from subprogram 'isnewvar'
	global exit = 0											// Signals to wrappr that lower-level prog exitd due to 'exit 1' commnd
															// $exit==1 requires restoration of origdta; $exit==2 does not
															// 'exit 1' is a commnd unlike $exit=1, which is a flag for callng prog
															
	local prfxvars = ""										// Cumulative list of prefix vars mentioned in successive varlists
	local keepwtv = ""										// Will hold list of weightvars, to be kept in working data
	local wtexplst = ""										// Will hold list of weight expressions to be passed to `cmd'P
	
	local nvarlst = 0										// Count of varlsts in the multivarlst (defaults to 0, flaggng an error)

	capture confirm variable SMstkid						// See if dataset is already stacked
	if _rc  local stackid = ""								// `stackid' holds varname SMstkid or indicates its absence if empty

	else  {
		local stackid = "SMstkid"							// Else record name of stackid in local stackid
		capture confirm variable S2stkid					// See if dataset is already doubly-stacked
		if _rc  local dblystkd = ""							// if not, empty the indicator
		else local dblystkd = "dblystkd" 					// Else record name of double-stack id in local dblystkd
		global dblystkd = "`dblystkd'"						// And make a global copy accessible to genstacksP
	}

	local multivarlst = ""									// Local that will hold (list of) varlist(s)
	local noweight = "noweight"								// Default setting assumes no weight expression appended to any varlist

/*
	local varmis = 										   ///
	"varmis1 varmis2 varmis3 varmis4 varmis5 varmis6 varmis7 varmis8 varmis9 varmis10 varmis11 varmis12 varmis13 varmis14 varmis15"
*/
	quietly {
	  forvalues i = 1/15  {									// All 3 lists need to be initialized to null
		local wtvar`i' = ""	
		local varmis`i' = ""
	  }	//next `i'											// By initializing the above we ensure Stata knows they are local names
	} //end quietly
	
	local needopts = 1										// MOST COMMANDS REQUIRE OPTIONS-LIST (exceptns at top of codeblk 0.1)
															// (MORE NOW THAT CONTEXTS AND STACKS NO LONGER DECALERED in `cmd' line)`***'
	
	
	
	
															
pause (0.1)	

										// (0.1) Codeblock to pre-process the command-line passed from `cmd', the calling program.
										//       It divides up that line into its basic components: `cmd' (the stackMe commend name);
										//	    `anything' (the combined varlist/namelist and ifinwt expression); the comma followed 
										//	     by `options' appended to that expression; the syntax `mask' appended to the above;  
										//	     and two afterthoughts that are placed between the options and the mask.
											
											
	gettoken cmd rest : 0									// Get the command name from head of local `0' (what the user typed)
	global cmd = "`cmd'"									// (this command primes local `rest' for the opening while loop, below,
															//  and provides a global for use in other programs)
	if "`cmd'"=="gendummies"  local needopts = 0 			// ADD ANY OTHER EXCEPTIONS, AS DISCOVERED 								***
	gettoken cmdstr mask : rest, parse("\")					// Split rest' into the command string and the syntax mask
						
	gettoken preopt rest : cmdstr, parse(",")				// Locate start of option-string within cmdstring (it follows a comma)
	if substr("`rest'",1,1)=="," local rest = substr("`rest'",2,.) // Strip off "," that heads the mask
	
	if strpos("`rest'",",")>0 {								// Flag an error if there is another comma
		display as error "Only one options list is allowed with up to 15 varlists{txt}"
*               		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox stop "Only one options list is allowed with up to 15 varlists; will exit `cmd. on 'OK'"
	}
	
	gettoken options postopt : rest, parse("||")			// That optstring ends either with a "||" or with the end of cmdstring
															// (if it ends with "||" don't strip them from start of 'postop')
	local multivarlst = "`preopt' `postopt'"				// It doesn't matter where `options' sat within `cmdstr'; this code
															//  leaves us with complete `multivarlst' and separage `options' 
															// (Note that pipes left at start of 'postopt' now terminate 'preopt')
	

	
	
pause (0.2)
										// (0.2) Codeblock to extract the `prefixtype' argument and `multiCntxt' flag that preceed 
										//		 the parsing `mask' (see any calling `cmd' for details); discovers the option-name 
										//		 of the first argument – an argument that will hold a varname or list of varnames 
										//		 that might, if the user chooses, instead be supplied by a prefix to each varlist 
										//		 (varlist prefixes can be different for each varlist whereas options cannot).
												 
	
	local mask = strtrim("`mask'")
	
	if substr("`mask'",1,1)=="\"  {
	    local mask = strtrim(substr("`mask'",2,.)) 			// Trim off the backslash that sits at the head of `mask'
	}
	gettoken prfxtyp mask : mask							// Get `prfxtyp' option+argument (all in 1 word) from head of mask
	gettoken istwrd mask : mask								// See if 1st word of remaining `mask' is a `multicntxt' flag
	local multiCntxt = ""									// By default assume this cmd does NOT take advantage of multi-contxts
	if "`istwrd'"=="multicntxt"  {							// First option has differnt names in diffrnt cmds, hence double-quotes
		local multiCntxt = "multiCntxt"						// Reset multiCntxt local if `multicntxt' option is present.
	}
	
	else  {													// Else first word is not "multicntxt"
		local mask = "`istwrd'" + "`mask'"					// So re-assemble mask by prepending whatever was in 1st word to rest
	}														//  of mask; but with "multicntxt" flag and leading "\" removed
	gettoken preparen postparen : mask, parse("(")			// Identify the option-name for that 1st option by parsing on "("
	local opt1 = lower("`preparen'")						// Deal with any capitalized initial chars in this option name
															// (leaves the lower case version of 1st optn in 'opt1', needed below)
	local saveoptions = "`options' `prfxtyp'"				// Append 'prfxtyp' to 'options' so it can be parsed by syntax command
															// (along with user-supplied options)
	if substr("`saveoptions'",-1,1)=="\" {					// THESE 4 LINES CAN GO once the space following "\" is removed from all
	    local l = strlen("`saveoptions'")					//  calling programs
		local saveoptions = substr("`saveoptions'",1,`l'-1)
	}														// Use `saveoptions' 'cos `options' will be schlockd by next syntax cmd

	local optionsP = "`saveoptions'"						// The options that will be passed on to 'cmd'P
	
	
	
	
pause (0.3)


										// (0.3) Deal with special case of genstacks variable/stub list and options
										//	     (genstacks only has one varlist so need not be processed w other commands)
	  
	
	if "`cmd'"=="genstacks" {								// If dataset is about to be stacked ...					

		local frstwrd = word("`multivarlst'",1)				//`multivarlst' from codeblk (0)
															// (reconstruction in codeblk 1.1 was skipped for genstacks)
		local test = real(substr("`frstwrd'",-1,1))			// See if final char of first word is numeric suffix
		local isStub = `test'==.							//`isStub' is true if result of conversion is missing

		if `isStub'  {										// If user named a stub, need list of implied vars to keep
															//  in working data
			local reshapeStubs = "`multivarlst'"			// Stata's reshape expects a list of stubs
															// (which is what should be held in 'multivarlst')
*			******************
			varsImpliedByStubs `reshapeStubs'				// Call on appended program
*			******************

			local impliedVars = r(keepv)					// Implied by the stubs actually specified by user

			if strpos("`impliedvars'",".")>0  {
				display as error "Could not determine vars implied by these seeming stubs{txt}"
*               		  		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				capture window stopbox stop "Could not determine vars implied by seeming stubs; will exit on 'OK'"
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
				
				display as error "Varlists don't match variables implied by their stubs. Use implied variables?{txt}"
*               		  		               12345678901234567890123456789012345678901234567890123456789012345678901234567890
				capture window stopbox rusure "Stubs from varlists imply vars that don't match those varlsts. Use implied vars?"
				if _rc   {									// Exit with error if user says "no" 
					window stopbox stop "Will exit on 'OK"
				}

				noi display "Execution continues ..."

				if strpos("`stublist'",".")  local stublist = subinstr("`stublist'", ".", "", .) // Strip missng indicatrs & go on
															// Eliminate any missing variable indicators from `stublist'
				local reshapeStubs = "`stublist'"			// Where stubs were stored if user listed them, before 'else', above

			  } //endif !`same'	

		} //endelse
															

		local nstubs = wordcount("`reshapeStubs'")			// Check that no stubnames already exist as variables
		
		local errlist = ""									// This local will store stubnames that already name a variable
		
		forvalues i = 1/`nstubs'  {
			local var = word("`reshapeStubs'",`i')
			capture confirm variable `var'
			if _rc==0  {									// Error if var already exists
				local errlist = "`errlist' `var'"
			}
		} //next `i'
		
		if "`errlist'"!=""  {
			display as error "Variable(s) already exist with stubname(s) `errlist'{txt}"
			window stopbox stop "Variable(s) already exist with stubname(s) `errlist'; will exit on 'OK'"
		}
				

		if "`itemname'"!=""  {								// In genstacks any 'itemname' option names var to be kept, below
			capture confirm variable `itemname'				// (it provides a link from each stack to other battery items)
			if _rc  {
				display as error "Option `itemname' does not name an existing variable{txt}"
				window stopbox stop "Option 'itemname' does not name an existing variable; will exit on 'OK'"
			}												// 'itemname' will override SMitemname dataset characteristic
			else {											// (created by genstacks)
				if `limitdiag' noisily display "Optioned itemname will override dataset characteristic set by 'genstacks'"
*               		  		            12345678901234567890123456789012345678901234567890123456789012345678901234567890
			}
		}													// Vars in 'varsImpliedByStubs' need to be kept in working data
															// (no SM.. variables in unstacked data)
															
		local keepimpliedvars = "`impliedVars' `itemname'"	// (genstacks does need SMunit, etc, supplied in (6) for workng dta													
														    // Most codeblcks from here on will end with a list of vars to keep

															
											
					
											
pause (0.4)		
	
										// (0.4)) For genstacks, additional vars are generally needed beyond those in `multivarlst'
										//		 Also need to see if genstacks is to doubly-stack the data or just singly stack.
										//		 Either way appropriate variables need to be created and flagged for keeping
															
		
		if "`nostacks'"!="" {
			display as error "'nostacks' cannot be optioned with command genstacks. Ignore and continue?{txt}"
			capture window stopbox rusure "'nostacks' cannot be optioned with command genstacks. Ignore and continue?"
*						 	                12345678901234567890123456789012345678901234567890123456789012345678901234567890	
			if _rc {
				window stopbox stop "Will exit on 'OK'"
			}												//  (no need to restore full dataset since not yet messed with)
			noi display "Execution continues ..."
			local nostacks = ""
		}													// This should never happen
		
		global dblystkd = ""								// Global used in `cmd'P must be empty if not doubly-stacked
		local dblystkd = ""
					
		capture confirm variable SMstkid					// No SMstkid means data not yet stacked
		
		if _rc ==0  {									
			local stackid = "SMstkid"  						// Return code of 0 indicates that the variable exists
			if `limitdiag'  {
				noisily display  "NOTE: This dataset appears to be stacked (has SMstkid variable){txt}"
				display as error "NOTE: Genstacks will try to doubly-stack these data; is that what you want?{txt}"				
*						 	   	   12345678901234567890123456789012345678901234567890123456789012345678901234567890	
				capture window stopbox rusure "Genstacks will try to doubly-stack these data; is that what you want?"
				if _rc  {
					global exit = 2							// (NOTE: 'exit 1' is a command that exits to the next level up
					exit 1									//  $exit=2 tells that program what do do when re-entered)
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
					global exit = 2							// (NOTE: 'exit 1' is a command that exits to the next level up
					exit 1									//  $exit=2 tells that program what do do when re-entered)
				}
				foreach var in SMunit SMnstks SMitem SMunit  {
					capture drop `var'
				}
				display as error "SMunit and any other 'SM' variables will be replaced as execution continues ...{txt}"
*						          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			} 												// Will need these vars for stacking 		** ONLY IN WORKING DTA		***
			
		} //endelse
		

		
		if "`dblystkd'"!=""  {								// If data are to be duubly-stacked (SMstkid already exists)
											
			capture confirm variable S2stkid				// S2stkid should not already exist in unstacked data
			
			if _rc == 0  {
				display as error "Variable S2stkid should not already exist in data to be doubly-stackd. Continue?{txt}"
				capture window stopbox rusure "Variable S2unit should not already exist in data not doubly-stacked. Continue anyway?"
*						 		  12345678901234567890123456789012345678901234567890123456789012345678901234567890	
				if _rc!=0  {
					window stopbox stop "Will exit on 'OK'
				}
				else  {
					foreach name in S2stkid S2nstks S2unit S2item {
					   capture drop `name'					// Drop these vars if they exist
					}
					display as error "S2stkid and any other 'S2' variables will be replaced as execution continues ..."
				}
			} //endif _rc==0												// WILL NEED THESE VARS FOR STACKING  ** ONLY IN WORKING DTA			***


/*			local label : variable label `SMstkid'			// COMMENTED OUT FOR NOW – TO SEE IF IT IS NEEDED						***
			local same : list impliedVars === label			// returns 1 in 'same' if 'impliedVars' & 'label' have same contents 	****
			if `same'==0  {
				display as error "SMstkid's label does not have same vars as 'impliedvars'{txt}"
				window stopbox stop "SMstkid's label does not have same vars as 'impliedvars'; will exit on 'OK'"
			}
			else  {
				
			}
*/															
		} //endif 'dblystkd'
		
		else {												// Not doubly-stacked
*			if `limitdiag' display as error  "NOTE: This dataset appears to be stacked (has SMstkid variable){txt}"
															// Existing SMstkid in genstacks does not mean already stacked
		}
		
	}  //endif 'cmd'==genstacks
			
			
			
			
			
			
	
	else  {													// Not cmd genstacks

		if "`stackid'"==""  {								// If there is no SMstkid, the data are not stacked
			if "`cmd'"=="genplace" {
				 display as error "Command {bf:genplace} requires stacked data{txt}"
				 window stopbox stop "Command genplace requires stacked data. Will exit `cmd' on 'OK'"
			} 
		} //endif											// SMstkid is included in workng data if referenced by user

		else  {												// Else have stackid
			capture confirm variable S2stkid				// So check if also have S2stkid
			if _rc==0  {
				local dblystkd = "dblystkd"
				if `limitdiag' noisily display "NOTE: This dataset appears to be doubly-stacked (has S2stkid variable){txt}"
*						 		               1234567890123456789012345678901234567890123456789012345678901234567890123
			}
			
		} //endelse
			
	} //endelse
																// SMstkid and other such will be put in working data 
																// (after 'origdta' has been saved)
																
	global dblystkd = "`dblystkd'"								// Make copy in global accessible from elsewhere

																// This codeblock does not yield any additionl vars to keep

																

pause (1)

										// (1) Process the options-list (found among the perhaps several varlists in codeblk 0.1)
										// 	   (currently only one options-list following final varlist)

										
	local keep = ""										// will hold 'opt1' from 0.2 plus contextvars itemname stackid if optd
	
	local options = "`saveoptions'"						// Retrieve `options' saved in codeblk 0.1
	
	if substr("`options'",1,1)==","  {					// If `options' (still) starts with ", " ... APPARENTLY IT DOESNT			***
		local options = strltrim(substr("`opts'",2,.))	// Trim off leading ",  " 
	}						
														// This code permits successive optlists to update active options
														// (experimantal code now redundant but retained pending future evolution)
														
	if "`options'"!=""  {								// If this varlist has any options appended ...							
	 
		local opts = "`options'"						// Cannot use `options' local as that gets overwritten by syntax cmd)\
		
		gettoken opt rest : opts, parse("(")			// Extract optname preceeding 1st open paren, else whole of word
														// NOTE: 'opt' and 'opts' are different locals

/*														// duprefix WAS NOT IMPLEMENTED IN THIS VERSION OF GENDUMMIES?				***				
		if "`cmd'"=="gendummies" &"`opt'"=="prefix" { 	// (any unrecognized options might be legacy option-names)
			display as error "'prefix' option is is named 'duprefix' in version 2. Exiting `cmd'." 
			window stopbox stop "Prefix option is named 'duprefix' in version 2. Exiting command."	
		}												// (also, `opt' is named `opt1', saved at end of codeblk 0.2)
*/		if "`cmd'"=="gendist"  {
		   if "`respondent'"!=""   {
		      display as error "Option 'respondent' is option 'selfplace' in version 2. Exiting `cmd'{txt}"
		      window stopbox stop "Option 'respondent' is option 'selfplace' in version 2. Exiting command on 'OK'"
		   }
		}
		

														// ('ifin' exprssns must be appended to first varlist, if more than one)
		local 0 = ",`opts' "  							// Named opts on following syntax cmd are common to all stackMe commands 		
														// (they supplement `mask' in `0' where syntax cmd expects to find them)
														// Initial `mask' (coded in the wrapper's calling `cmd' and pre-processed
														//  in codeblock 0 above) would apply to all option-lists `in multioptlst'
														//											 (dropped from current versn)
*		***************									// (NEW and MOD in this syntax command anticipate future development)		***
		syntax , [`mask' NODiag EXTradiag REPlace NEW MOD NOCONtexts NOSTAcks prfxtyp(string) * ] 
/*	    **************/	  							  	// `mask' was establishd in calling `cmd' and preprocssd in codeblk (0.2)
														// `new' replaced both NEWoptions and NEWexpressions; `mod' was default		***


														// Pre-process 'limititdiag' option
		if `limitdiag'== -1 local limitdiag = .			// Make that a very big number if user does not invoke this option
		if "`nodiag'"!=""  local limitdiag = 0			// One of the options added to `mask', above, 'cos presint for all cmds
		
		if ("`nostacks'" != "")  local stackid = "" 	// Ditto for SMstkid (genplace does not have this option)					***
		
														// Identify optioned var(lists) to keep; 'genplace' has two of them
				
														
*		local actn = 0									// Set action flag to 0	(actions identified when flag is reset)
	    local opterr = ""								// local will hold name(s) of misnamed var(s) discovered below
	    local optadd = ""								// local will hold names of optioned contextvars to add to keepvars


										//WHERE optionsP GETS ITS CONTENTS:  JUST BEFORE (0.3)

		
		
pause (1.1)


										// (1.1) Deal with 'contextvars' option/characteristic and others that add to the 
										//		 variables that need to be kept in the active data subset
										

*		**********************							// Implementing a 'contextvars' option involves getting charactrstic
		local contexts :  char _dta[contextvars]		// Retrieve contextvars established by SMcontextvars or prior 'cmd'
*		**********************							// (not to be confused with 'contextvars' user option)


*														// COMMENTED OUT BECAUSE OF MORE ELABORATE CODEBLOCK BELOW		
		local opterr = ""								// Empty this local which will carry an error message
		
		if `limitdiag'  {								// Much of what is done involves displaying diagnostics, if optioned
		
		  if "`contexts'"!=""  { 						// Characteristic shows existing contextvars
														// 'else' will be codeblk for no established contexts
			if "`contexts'"=="nocontexts"  {			// Contexts were defined as absent by SMcontextvars
			  noisily display ///
    "{txt}NOTE: stackMe utility {help stackme##SMcontextvars:SMcontextvars} defined this dataset as having no contexts{txt}"
*		         12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  local contexts = ""						// So we don't take "nocontexts" to be a variable name!
			}              								// Will be displayed after end of 'limitdiags' codeblock
			
			capture unab contexts : `contexts'			// Ensure 'contexts' contains valid varnames
			if _rc  {					
				display as error "{txt}This file's charactrstic names contextvar(s) that don't exist: `contexts'{txt}"
				display as error ///
		         "Use utility command {help stackme##SMcontextvars:SMcontextvars} to establish correct contextvars{txt}"
*		                          12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  window stopbox stop ///
					"This file's contextvars charactrstic names variable(s) that don't exist: `contexts'; will exit on 'OK'"
			} //endif

		    else  {										// Else data characteristic holds valid contextvars
				noisily display "Contextvars characteristic shows established contextvars: `contexts'{txt}" 			
*		         				 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			}
			
		  } //endif 'contexts'
		  
		  
		  else  {										// Else _dta[contextvars] characteristic was empty
		  
			local opterr =  /// 						//  Non-empty 'opterr' gets this msg displayed at end limitdiag
			     "stackMe utility {help stackme##SMcontextvars:SMcontextvars} hasn't initialized this dataset for stackMe"
*		                     12345678901234567890123456789012345678901234567890123456789012345678901234567890
 		  
			if "`contextvars'"!=""  {						// If contextvars were user-optioned
			  local same : list contexts === contextvars
			  if `same'  noisily display ///				// Returns 1 if two strings match (even if ordered differently)
				"Optioned contextvars match those established for this dataset by {cmdab:SMcon:textvars}{txt}"
*		         1234567890123456789012 3456789012345678901234567890123456789012345678901234567890
			}
			else  {
				noisily display ///
			   "Optioned contextvars temporarily override those established by {help stackme##SMcontextvars:SMcontextvars" 
			}
			
		  } //endelse
		  
		} //endif 'limitdiag'							// Next check involves an actual error that terminates execution
	
		
		if "`opterr'"!=""  {
		   display as error "`opterr'"
		   if "`contextvars'"!=""  {					// If user optioned contextvars
*		                         12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  capture window stopbox rusure ///
					"Use optioned contextvars instead?"
			  if _rc  {
			  	 window stopbox stop ///
			"Use stackMe utility {help stackme##SMcontextvars:SMcontextvars} to initialize this dataset; will exit on 'OK'"
			  }
			  local contexts = "`contextvars'"
			  char define _dta[contextvars] `contexts' // Establish new data characteristic 'contextvars'
			  noisily display "NOTE: redundant 'contextvars' option duplicates established contexts{txt}"
		   }
		   
		   else  {
		     display as error "Use utility command {help stackme##SMcontextvars:SMcontextvars} to initialize this dataset{txt}"
*		                       2345678901234567890123456789012345678901234567890123456789012345678901234567890
		   	 window stopbox stop  "Use utility command SMcontextvars} to initialize this dataset; will exit on 'OK'"
		   }
		} //endif 'opterr'
		
		local contextvars = "`contexts'"				// Change of name fits with usage elsewhere in stackMe

	

/*														// FOLLOWING CODE COMMENTED OUT 'COS REPLACED BY ABOVE CODEBLK
		if "`contexts'"!=""  {							// If characteristic holds contextvars
			
			capture unab contexts : `contexts'			// Ensure 'contexts' contains valid varnames
			if _rc  {					
				display as error "This file's charactrstic names contextvar(s) that don't exist: `contexts'{txt}"
				display as error ///
		         "Use utility command {help stackme##SMcontextvars:SMcontextvars} to establish correct contextvars{txt}"
*		                          12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  window stopbox stop ///
					"This file's contextvars charactrstic names variable(s) that don't exist: `contexts'; will exit on 'OK'"
			} //endif
		  
		} //endif

														
		if "`contextvars'"!=""  {						// If `contextvars' have been user-optioned
														// These will replace characteristic contexts or cause error exit

		    capture unab optadd : `contextvars'			// Re-use 'optadd' which passed its contents to 'context' just above
		    if _rc  {									// Do these 'contextvars' exist?
			   display as error "Option 'contextvars' names variable(s) that don't exist"
			   window stopbox stop "Option 'contextvars' names variable(s) that don't exist; will exit on 'OK'"
		    }
		   
		    else {										// Else 'contextvars' option names valid variables
			
			  if "`contexts'"!=""  {					// If there was also a contexts characteristic...
			     if `limitdiag'  noisily display "NOTE: established contexts overridden by optioned: `contextvars'{txt}"
			  }											// Here we need explicit 'if' 'cos codeblk not subject to 'limitdiag'
			  
			} //endelse
		
			if "`opterr'"!=""  {						// Ask user if replace missing charactristic w `contextvars'
			
				display as error "`opterr'"
				display as error "Use optioned variables to satisfy SMcontextvars needs?{txt}"
*							      12345678901234567890123456789012345678901234567890123456789012345678901234567890
				capture window stopbox rusure "`opterr'; use optioned variables to satisfy SMcontextvars needs?"
				if _rc  {
				   window stopbox stop "Will end execution on 'OK'"
				}
				else  {									// Else 'OK' to updating 'contextvars' to hold established contexts
				   char define _dta[contextvars] `optadd' 
				} //endelse
				
			} //endif 'actn'							// Put optioned 'contextvars' where SMcontextvars would have done

			
			
			local same : list contexts === optadd		// returns 1 in 'same' if 'contexts' & 'optadd' contents match 
														// (not necessarily in same order)
			if `same'  {
				noisily display "NOTE: redundant 'contextvars' option duplicates established contexts{txt}"
			}
			
			else  {										// 'contextvars' names different contexts than established ones
			  	noisily display "NOTE: established contextvars temporarily modified by optioned contextvars{txt}"
			} //endelse
			
		} //endif'contextvars'
		
		local contextvars = "`contexts'"				// Change of name fits with usage elsewhere in stackMe

*/														// ABOVE CODE COMMENTED OUT 'COS REPLACED BY EARLIER CODEBLOCK

		
		local optad1 = ""								// Will hold indicator or cweight options
		local optad2 = ""								// Additional local to hold the other of 'cweight's two varname options
	
		local opterr = ""								// Reset opterr 'cos already dealt with previous set of error varnames

		
		if "``opt1''"!="" & "`prfxtyp'"=="var"  {		// (was not derived from above syntax cmd but from end of codeblk 0.2)
		   local temp = "`opt1"							// If 'cmd' is 'genplace', `opt1' will point to `cweight' or "indicator"
		   foreach var of local temp  {					// Local temp gets varname/varlist pointed to by "``opt1'"
			  capture confirm variable `var'			// See if all these vars exist
			  if _rc local opterr = "`opterr' `var'"	// Extend 'opterr' if not
			  else local optad1 = "`optad1' `var'"		// Extend 'optad1' otherwise
		   }					
	    }	
		
		if "`cmd'"=="genplace"  {						// If this is as a 'genplace' command line there could be two varlsts
														// `genplace' has an additional option, tricky to identify
		  if "`opt1'"=="indicator" & "`cweight'"!="" {	// If `cweight' is optioned as well as `indicator'
		    local temp = "`cweight'"					// put in `temp' the varname/varlist that 'opt1' points to
			foreach var of local temp  {				// Cycle thru all vars in 'temp'
		      capture confirm variable `var'			// See if 'opt1' ("indicator") is a valid varname
		      if _rc local opterr ="`opterr' `cweight'" // (and var named by 'cweight' does not exist, extend 'opterr')
		      else local optad1 = "`optad1' `cweight'"	// Else extend varlist in 'optadd' to save it in
		    }
	 	  } //endif 'opt1'
		
		  if "`opt1'"=="cweight" & "`indicator'"!="" {	// If 'indicator' is optioned as well as 'opt1' ("cweight")
		    local temp = `indicator'
			foreach var of local temp  {
		      capture confirm variable `var'			 //  and var named by 'indicator' doesn't exist, 
		      if _rc local opterr="`opterr' `indicator'" // Extend 'opterr' with additional optioned variable
		      else local optad2 = "`optad2' `cweight'"	 // Else extend varlist in `optad2' to save it in
			}
	      }
		 		
	      if "`opterr'"!=""  {							 // Here issue generic error msg if codeblk found any naming errors
		     display as error "Invalid optioned varname(s): `opterr'{txt}"
		     window stopbox stop "Invalid optioned varname(s): `opterr'; will exit on 'OK'"				
	      }
		  
		} //endif  'cmd'=='genplace
		
		
		if "`itemname'"!=""  {							// User has optioned an SMitem-linked variable
		   capture confirm variable `itemname'
		   if _rc  {
		      display as error "Optioned {opt itemname} is not an existing variable{txt}"
			  window stopbox stop "Optioned {opt itemname} is not an existing variable; will exit on 'OK'"
		   }
		   
		}
		
				
	    if "``opt1''"!="" & "`prfxtyp'"=="var" {			  // If first option names a variable
		
		   local keepvars = "``opt1''"
		   foreach var of local keepvars  {
		     capture confirm variable `var'
		     if _rc  local opterr = "`opterr' `var'"
		     else local optadd = "`optadd' `keepvars'"
		   }
		   if "`opterr'"!=""  {
			  display as error "Variable(s) in 'opt1' not found: `opterr'. Exiting `cmd'{txt}"
			  window stopbox stop "Variable(s) in 'opt1' not found: `opterr'; will exit 'cmd' on 'OK'."
		   }
		 
		} //endif 'opt1'

		local lastwrd = word("`opts'", wordcount("`opts'"))	  // Extract lst wrd of `opts', placed there in 0.2 & parsed in 1.0
		local optionsP = subinword("`opts'","`lastwrd'","",1) // Save 'opts' minus its last word (the added 'prfxtyp' option)
															  // (put in 'optionsP' to be passed to 'cmd'P)
														  
	} //endif 'options'

	
															
	local keepoptvars = strtrim(stritrim(		///		 	  // Trim extra spaces from before, after and between names to be kept
		"`contextvars' `optadd' `optad1' `optad2'"))		  // Put all these option-related variables into keepoptvars 
															  // SMstkid and other stacking identifiers will be handled separately
															  // TWICE MENTIONS VAR TO BE KEPT (DO CHECK FOR THIS) DK WHY			***
																	
	
	
	
	
	
pause (2)
										// (2)  Ignoring genstacks (dealt with in codeblk 1 above), this codeblock extracts each
										//		varlist in turn from the pipe-delimited multivarlst and, after sorting the variables
										//		into input and outcome lists, pre-processes if/in/weight expressns for each varlist,
										//		then re-assembles those varlsts, shorn of 'ifinwt' expressns, into a new multivarlst
										//		that can be bassed to whatever 'cmnd'P is currentlu being processed.
	
	
	if "`cmd'"!="genstacks"  {									// 'genstacks' command-line was processed in codeblks 1.1 and 1.2
																// (it only has a single stublist and no 'ifinwt' expressions)
	   local varlists = "`multivarlst'"							// Here we process multivarlsts for other commands
																// Put the 'multivarlst' (from end of codeblk 0.1) into 'varlists' 
	   local multivarlst = ""									// Then empty it to be refilled with varlists shorn of ifinwt,opts
																// ('multivarlst' is reconstructed towards end of this codeblk)
	   local lastvarlst = 0										// Will be reset =1 when final varlist is identified as such
	   local keepvarlsts = ""									// This will hold 'inputs' `outcomes'`ifvar' `keepwtv', if referencd														
	   local outcomes = ""										// These vars will become string-prefixed outcome variables
	   local inputs = ""										// Only for 'genyhats' does one of these morph into an outcome var
	   local strprfx = ""										// (for other 'cmd's 'inputs' will hold supplementary input vars)
	   local strprfxlst = ""									// List of prefix strings; check in (3) not mistook for vars
	   local keepwtv = ""										// List of pseudo-weight vars to be kept in (2.2)	
	   local temp = ""											// This will hold a genyhats prfxvar (the tail of a double-prefix)
	   local errlst = ""										// List of supposed varnames found not to exist
	   local opterr = ""										// Used repeatedly to collect list of erronious varnames
	   local ifvar = ""											// Optionally filled later in this codeblk
	   local wtexplst = ""										// Optionally filled later in this codeblk
	   local noweight = "noweight"								// Flag indicates no weight expression as yet for any varlist
	  
	
	
	
*	    ***********************	  
	    while "`varlists'"!= ""  {									// Repeat while another pipe-delimited segment remains in 'varlists'
*	    ***********************										// (so rest of codeblk is collecting lists of items, 1 per varlist)							
																	// Here parse the stackMe varlist, generally with following format:
																	// [[string_]inputvar(s):] outcomevars [ifin][weight] [no opts here]
																	// (strictly, all vars are inputs; some yield str-prefxed outcomes)

		   gettoken anything varlists : varlists, parse("||")		// Put successive varlists (delimited by "||") into 'anything'
		   if "`varlists'"==""  local lastvarlst = 1				// If more pipes don't follow this 'varlist', reset 'lastvarlst'=1 
		   else local varlists = strtrim(substr("`varlists'"),3,.)	// Else remove those pipes from what is now the head of 'varlists'
																	// (and trim off any following blanks)
																
		   local nvarlst = `nvarlst' + 1							// `nvarlst' from cdblk 0, line 58, counts n of varlists in cmd
																
		   local 0 = "`anything'"									// This is the varlist [if][in][weight], options typed by the user
																	// (placed in local `0' because that is what 'syntax' cmd expects)
	

		   ***************	
		   syntax anything [if][in][fw iw aw pw/]		  			// `mask' was set in calling `cmd' and preprocssd in codeblk (0.2)
*	       ***************	  					
																	// (trailing "/" ensures that weight 'exp' does not start with "=")
																	// Syntax command strips `anything' of following 'ifinwt' & options
		   if `nvarlst'==1  {
			  local ifin = "`if' `in'"								// Ensure 'if' and 'in' expressns occur only on first varlist
		
			  if "`if'" != ""  {									// If not empty, calls for `if' when establishing a working dataset
				 tempvar ifvar										// Create a temporary variable to indicate which obs will be kept
				 gen `ifvar' = 0									// Don't know name(s) of vars in 'if' expression but can substitute 
				 qui replace `ifvar' = 1 `if'						//  this indicator whose name is known
				 local ifexp = "if `ifvar'"							// Local will be empty if none. NOTE there is only one ifexp per cmd
			  } //endif `if'
		
			  if "`in'"!=""  {										// If not empty, calls for `in' when establishng the working dataset
				 local inexp = "`in'" 								// Store in inexp
			  } //endif `in'										// If "'inexp`nvl''"!="" code "`inexp`nvl''" in codeblock 6 below
																	// Weight expressions will be evaluated varlist by varlist
		   } //endif 'nvarlst'==1
		   
		   else  {													// Else 'nvarlst' > 1; later varlists should not affect ifin expressns
		      local ifin = "`if' `in'"
		   	  if "`ifin'"!=""  {
		   		  display as error "Only 'weight' expressions are allowed on varlists beyond the first; not if or in{txt}"
*               		  	  		12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  window stopbox stop "Only 'weight' expression' are allowed on varlists beyond the first; not 'if' or 'in'"
			  }								
		   } //endelse
		   
		   
		   if "`weight'"!=""  {										// If a weight expression was appended to the current varlist

			  local wtexp = subinstr("[`weight'=`exp']"," ","$",.)	// The trailing "/" in the weight syntax eliminates redundnt blank
																	// Substitute $ for space throughout weight expression																// (has to be reversed for each varlist processed in 'cmd'P)
*		 	  ***************										// (ensures one word per weight expression)
			  getwtvars `wtexp'										// Invoke subprogram 'getwtvars' below
*		 	  ***************	
	   
			  local wtvars = r(wtvars)
			  local keepwtv = "`keepwtv' " + r(wtvars)				// Append to keepwtv the 1 or 2 vars extracted by prog 'getwtvars'
		   
			  local noweight = ""									// Turn off 'noweight' flag; calls for full tracking across varlsts
		 
			  while wordcount("`wtexplst'")<`nvarlst'-1  {			// While 'wtexplst' is missing any previous weight expressions..
				local wtexplst = "`wtexplst' null"					//  pad 'wtexplst' with "null" strings for each missing word
			  }														// Padding ends with previous 'nvarlst'
			  local wtexplst = "`wtexplst' `wtexp'"					// Append current weight expressions to list for passing to `cmd'P
			  
		   } //endif 'weight'
		

		   else  {													// Else there was no weight expression appended to this varlst

			 if "`noweight'"==""  {									// If there was a previous `wtexp' (so this is not first 'nvarlst')
			   while wordcount("`wtexplst'"<`nvarlst'  {			// While previous 'wtexp' expression was missing
				 local wtexplst = "`wtexplst' null"					//  pad the `wtexplst' with null strings for each missing word
			   }													// (insures 'wtexplst' remains empty when passed to 'cmd'P)

			 } //endif `noweight'
			 
		   } //endelse	
		   
		   local llen : list sizeof wtexplst
	  
		   while `llen'<`nvarlst'  {								// Finish up the wtexplst
			 local wtexplst = "`wtexplst' null"					// Pad any terminal missing 'wtexplst's (must be after 'endwhile')
			 local llen : list sizeof wtexplst
		   }		  

		   
		   gettoken precolon postcolon : anything, parse(":")		// Parse components of 'anything' based on position of ":", if any
		   if "`postcolon'"==""  {									// If 'postcolon' is empty then there is no colon
			  unab vars : `anything'								// Stata will report an error if var(s) do not exist
			  local outcomes = "`outcomes' `vars'"					// If there is no colon then 'outcomes' is extended with new 'vars' 
		   }														
		
		   else  {													// There is a colon, so 'outcome' gets (perhaps tail of) 'precolon'

		     if "`cmd'"=="gendummies"  {
			 	noisily display _newline "NOTE: Prefix to varlist overrides, for that varlist, any stubname option{txt}"
			 	local strprfx = "`strprfx'_`precolon'" 				// For gendummies 'precolon' is a varname prefix
				local vars = strtrim(substr("`postcolon'",2,.))		// 'vars' is remainder of 'postcolon' after ":" is removed from head
				unab vars : `vars'									// Unabbreviate and check that vars exist
				local outcomes = "`outcomes' `vars'"				// Extend 'putcomes' list with 'vars'
			 }
			 
		     else {													// Else cmd is not gendummies
			 	
		        gettoken preul postul : precolon, parse("_")		// Is there a "_"-prefixed varname prefixing the precolon var(list)?
		        if "`postul'"!=""  {								// If 'postul' is not empty its contents are generally input vars
			       local temp = substr("`postul'",2,.)				// (strip undrline from head of 'postul'; `cmd'P will hndle `preul')
				   local prfxvar = "`temp'"							// In the general case 'temp' is a prefixvar
		           if "`cmd'"!="genyhats"  {						// (special treatment for 'genyhats' will follow the next 'else')
		              local inputs = "`inputs' `temp'"				// So append what was 'temp' to 'inputs' list
			       }												// (these are inputs that are not outcomes)
				   else  {											// Else command is genyhats (only 'cmd' where 'precolon' is a depvar)
					 local outcomes = "`outcomes' `temp'"			// Append to outcomes from previous var(list)s
				   } //endelse										// (these are outcomes that are also inputs)
				
				   local strprfxlst = "`strprfxlst' `preul'"		// And accumulate in strprfxlst the strprfx, if any, for each varlist
																	// (since 'postul' is not empty there must be a 'preul')
				} //endif 'postul'
			  
		        else  {												// Else precolon var has no "_" to define a prior string-prefix
				
				   local prfxvar = "`precolon'"						// So 'precolon' is a prefixvar
				   local postc = substr("`postcolon'",2,.)			// Strip the first char (a colon) from head of 'postc'
				   if "`cmd'"!="genyhats"  {						// Special treatment for 'genyhats' after next 'else'
		   	         local inputs = "`inputs' `precolon'"			// In the general case append each 'precolon' to 'inputs' list
				     local outcomes = "`outcomes' `postc'"			// (and append postc to outcomes from previous var(list)s)
			       }												// (the post-colon varlists all hold outcomes that are also inputs)
				   
			       else  {											// Else this is a 'genyhats' command
				     local outcomes = "`outcomes' `precolon'"		// For genyh any pre-colon var is the depvars (one per varlist)
				     local inputs = "`inputs' `postc'"				// (and the post-colon varlists list inputs that are not outcomes)
		           }
				
			    } //endelse 'cmd'=='genyhats'
			  
		     } //endelse `cmd'=='gendummies'						// NOTE: 'precolon' is neither outcome nor input for gendummies

	      } //endelse 'postcolon'
		
				
	      local multivarlst = "`multivarlst' `anything' ||"		// Here multivarlst is reconstructed without any 'ifinwt' expressns
																// (any such were removed by Stata's syntax command; instead weights
																//  per varlst were encoded in `wtexplst', above, to be sent to cmdP)

													
	      if `lastvarlst'  continue, break						// If this was identified as the final list of vars or stubs,						
																// ('break' ensures next line to be executed follows "} next while")

*	    ****************					
	    } //next `while'										// End of code processing successive varlists within multivarlst
*	    ****************										// Local lists processed below cover all varlists in multivarlst


		local llen : list sizeof wtexplst						// Finish up the wtexplst now all varlists have been processed
	  
		while `llen'<`nvarlst'  {	
	  	  local wtexplst = "`wtexplst' null"					// Pad any terminal missing 'wtexplst's (must be after 'endwhile')
		  local llen : list sizeof wtexplst
		}		  

			
			
			
			
pause (2.1)



										// (2.1) Here check on validity of vars in 'inputs' and 'outcomes'

   
		local check = strtrim(stritrim("`inputs' `outcomes'"))	// Check for variable naming errors among inputs & outcomes
																// (first extract all redundant spaces)
																
		checkSM "`check'"										// Call on subprogram listed following end of 'stackmeWrapper'
																// SHOULD BE SPLIT INTO 'chknew' and 'chkSM'						***
		local check = r(check)									// Vars remaining in 'check' are good to go
		local gotSMvars = r(gotSMvars)
	
	    local keepvarlsts = "`keepvarlsts' `varlst' `optadd' `check' `gotSMvars'" 
		local keepvarlsts = strtrim(subinstr("`keepvarlsts'",".","",.))	// Eliminate any "." in 'keepvarlsts' (DK where orignatd)
																// Check is added 'cos would have exited had check not succeeded
																// ('check' includes both inputs and outcomes)
		
		


	
pause (3)

		
										// (3) Checks various options specific to certain commands for correct syntax; adds `opt1'
										//	   (and 'opt2 for genplace) to 'keep' list if it is a variable.
										
										
		if "`strprfxlst'"!=""  {								// If we found a strprfx for any command ..
	       foreach item of local `strprfx' {					// Check if `varlists' from (2) accidentally has any of them
		      local keepanything = subinstr("`keepvarlsts'", "`item'", "", .) // If so, remove them (should be redundant)
		   }
		} //endif
		
																// genii & genpl can have multiple prefix vars (other cmds not)
		if wordcount("`inputs'")>1 & "`cmd'"!="geniimpute" & "`cmd'"!="genplace"  {
			 display as error "`cmd' cannot have multiple 'prefix:' vars (only geniimpute & genplace){txt}"
*                		  	     12345678901234567890123456789012345678901234567890123456789012345678901234567890
			 window stopbox stop "`cmd' cannot have multiple 'prefix:' vars (only geniimpute & genplace); will exit on 'OK'"
		} //endif wordcount
																// End of code interpreting prefix types

		local keepvarlsts = "`keepvarlsts' `ifvar' `keepwtv'"	// Must be appended after exiting 'while' loop `cos only done once 
																
																// List of vars/stubs will provide names of vars generatd by 'cmd'
	} //endif cmd != 'genstacks									// Otherwise repeat the while loop to process next var/stub list
	
	
	
	   	
																// Need spaces to replace colons; then trim extra spaces	
	
	if "`cmd'"=="genplace" & "`indicator'"!=""  {				// `genplace' is the only cmd with additional var-naming optn 		***
																// (beyond the 'opt1' option handled above; so handle it here)
																
		local errstr = ""										// Set error string initially blank
		local ifloc = strpos("`indicator'"," if ") 				// Word 'if' is blank-delimited in this option-string
				
		if `ifloc'>0  {											// If it exists within "`indicator'" string
			local ifind = substr("`indicator'",`ifloc',.) 		// Extract blank-delimted if-expressn & put in local `ifind'
			local ind = substr("`indicator'",1,`ifloc')   		// Place associated varname in local 'ind'
			local ind = strtrim("`ind'")						// Remove any leading or trailing blanks from varname
			capture confirm variable `ind'						// Confirm whether that variable exists
				  
			if _rc  {											// If return code is non-zero then `ind' does not exist
				qui generate `indicator' = 0					// So generate a new var with 'indicator' name, 0 by default
				qui replace `indicator' = 1 `ifind'				// Replace values of that variable to accord with 'ifind'
			}													// ('indicator' var now holds either orig or modified data)
																// Otherwise 'indicator' already exists; put that in 'errstr' 
			else local errstr = "'indicator if' should generate a new variable; but this var already exists"
*								  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		} //endif `ifloc'
				
		else  capture confirm variable `indicator'				// Else there is no `if'-expression; check that var exists
		if _rc  {												// Set error string to message if return code is non-zero
			local errstr = "Without 'if' suffix, named indicator variable should exist but does not"
		}
				
		if "`errstr'"!=""  {									// Non-empty 'errstr': there was an error in option string
			display as error "`errstr'{txt}
			window stopbox stop "`errstr'; 'genplace' will exit on 'OK'"
		}
				
		local keepprfx = "`keepprfx' `indicator'"				// If valid, save in 'keepprfx' as though it was a prfx


	} //endif 'cmd'=='genplace	
	
	
	capture erase `origdta'										// Before making any changes to data being processed ...
	capture drop `origunit'
	tempfile origdta											// Temporary file in which full dataset will be saved	
	tempvar origunit											// Temporary var inserted into every stackMe dataset; (enables
	gen `origunit' = _n											//  merge of newly created vars with original data in codeblk 9)
																// Equivalent to 'default' frame which, however, runs more slowly	

	
	local keepvars = strtrim(stritrim(	///						// Include just-created 'origunit' which we need for merging back
				"`keepvarlsts' `inputs' `outcomes' `keepimpliedvars' `keepoptvars' `keepprfx' `keepstubs' `origunit'"))


		



pause (4)
	
		
										// (4) Initialize ID variables needed for stacking and TO merge working data back 
										//	   into original data. Ensure all vars to be kept actually exist, remove any 
										//	   duplicates, check for accidental duplication of existing vars. Here we deal 
										//     with all kept vars, from whatever varlist in the multivarlst set
										   
																
															
*	************
	quietly save `origdta'								    // Will be merged with processed data after last call on `cmd'P
*	************											// (Changes to working data made below should be temporary)


	local temp = ""											// Name of file/frame with processed vars for first context
	local appendtemp = ""									// Names of files with processed vars for each subsequent contx
			
	local keep = "`keepvars'"
	
	local keep = strltrim(subinstr("`keep'", ":", " ", .))	// Remove any colons that might have been in 'saveAnything'
	local keep = stritrim(subinstr("`keep'","||", " ", .))	// Remove any pipes ditto AGAIN THESE ARE PROBABLY NOW REDUNDANT		***

			
	local keepvars : list uniq keep							// Stata-provided macro function to delete duplicate vars
	

*	*****************										// Check that all vars to be kept are actual vars
	capture unab keep : `keep'								// (stackMe does not support TS operators)
*	*****************										// (May include SMitem or S2item generated just above)
	

			
				
			
	
			
pause (5)


										// (5) Deal with possibility that prefixed outcome variables already exist, or will exist
										//	   when default prefixes are changed, per user option. This calls for two lists of
										//	   variables: one with default prefix strings and one with prefix strings revised in
										//	   light of user options. Actual renaming in light of user optns happns in the caller
										//	   program for each 'cmd' after processing by 'cmd'P; but users need to known before
										//	   cmd'P is called whether there are name conflicts. Meanwhile we must deal with any 
										//	   existing names that may conflct with outcome names, perhaps only after renaming.
	

	
	unab keepanything : `outcomes'							// List of outcome variables collected in codeblock (2)
	local check = ""										// Default-prefixed vars to be checked by subprog `isnewvar' below
	global prefixedvars = ""								// List of these to be extended by subprogram isnewvar (below)
	global exists = ""										// Ditto, for list of vars with revised prefixes if optioned
	global badvars = ""										// Ditto, vars w capitalized prefix, maybe due to prev error exit
															// (isnewvar calld from each prefix-relatd codeblock that follows)

															
	if "`cmd'"=="gendist"  {								// Commands should not create a prefixed-var that already exists

		foreach var of local keepanything  {				// Only vars to be used as stubs need be checked
		   foreach prfx in d m p x  {						// Default prfx names just one char, used (eg) in option 'dprefix'
		      local pfx = "d`prfx'"							// Construct corresponding outcome prefix with extra "d" for "dist"
			  if "`prfx'prefix"!="" {						// If 'prfx'prefix (eg 'dprefix') was optioned
				local pfx = "d`prfx'prefix"					// (then substitute that prefix for the default prefix)
			  }
			  local check = "`check' d`pfx'_`var'"			// Prepend whichever prefix to '_var' and add to check-list
		   } //next prfx									// (Only if optioned is there chance of a merge conflct, subroutine
		} //next var										//  'isnewvar' checks whether the prefixed var exists in 'origdta')
															// (program isnewvar, below, asks for permission to replace if so)
		isnewvar `check', prefix("null")					// Subprogram 'isnewvar' will add to $exists list if already exists
															// (permission to drop vars in that list will be sought following
	} //endif `cmd'=='gendist'								//  'genyhats' codeblock, below)
															// 'null' option signals no separate list of default-prefixed vars
	
	
	if "`cmd'"=="gendummies" {								// Commands should not create a prefixed-var that already exists
															// (gendummies concern is quite different from other 'cmd's)
	  foreach s of local keepanything  {					// DUPREFIX NOT IMPLIMENTED IN THIS VERSION OF gendummies					***
	  	
	  	local stub = "`s'"									// By default the stubname is the name of the categorical var
		if "`stubname'"!=""  local stub = "`stubname'"		// Replace with optioned stubname, if any
/*		local prfx = "du_"									// Gendummies has non-standrd prefix-strng usage; this is default
		if "`noduprefix'"!="" local prfx = ""				// If 'noduprefix' is optioned, prepend empty string
		if "`duprefix'"!="" & substr("`duprfix'",-1,1)!="_"  { // SEE ABOVE CAPITALIZED COMMENT
		    local prfx = "`duprefix'_"						// If `duprefix' is optioned, prepend that to varname
		}													// (having first appended the end-of-stub marker "_", if needed)
		else local prfx = "`duprefix'"
*/		
		quietly levelsof `s', local(list)					// Put in 'list' the values that will suffix each new varstubs
		local llen : list sizeof list						// How long is this list?
		if `llen'>15  {										// If greater than 15 new vars				
			display as error ///							   
	    "Variable `stub' generates `llen' new vars; see {help gendummies##categoricalVars:SPECIAL NOTE ON CATEGORICAL VARS}{txt}"
*						      12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			capture window stopbox rusure ///
			     "Variable `stub' will generate `llen' new vars – see gendummies SPECIAL NOTE; continue anyway?"
			if _rc  {
				 window stopbox stop "Will exit `cmd' on 'OK'"
			}
		    noisily display "Execution continues ..."
		} //endif 'llen'									// If we emerge from this codeblk
		
		if "`includemissing'"!=""  {						// If 'includemissing' was optioned, generate var w' 'mis' suffix
		   local check = "`check' `prfx'`stub'mis" )		// SEE IF THIS MATCHES WHAT I DO IN gendummies							***
		}													// (and append to 'check' - only once nomatter how many there are)
		
		foreach n of local list  {							// 'list' is the list of values (levels) that will suffix the stub
		   local check = "`check' `prfx'`stub'`n'"			// Generate varnamess by adding numeric suffix to stubnames
		} //next var										// (inclusion of `prfx' just adds a leading blank if there is no 'prfx')
															// (insurance in case we decide to use a 'du_-prefix)
		isnewvar `check', prefix(null)						// Subprogram 'isnewvar' will add to $exists list if already exists
															// (permission to drop vars in that list will be sought following
	  } //next 's'											//  'genyhats' codeblock, below)
															// 'null' option signals no separate list of default-prefixed vars
	} //endif 'cmd'=='gendummies'

	

	if "`cmd'"=="geniimpute"  {								// See comments under 'if 'cmd'=='gendist' above for explication

		foreach var of local keepanything  {
			local pfx = "ii"								// Default 'ii' prefix
			if "`iprefix'"!=""  local pfx = "i`iprefix'"	// Replace if 'iprefix' was optioned
			local check = "`check' `pfx'_`var'"				// Check to see if relevant prefixed var already exists
															
			local pfx = "im"								// Same for 'im' prefix
			if "`mprefix'"!=""  local pfx = "i`mprefix'"
			local check = "`check' `pfx'_`var'"
		} //next var										// If "$exists", below, asks for permission to replace
															// ($exists is filled by subprogram isnewvar, called here)
		isnewvar `check', prefix(null)						// Subprogram 'isnewvar' extends $exists list if already exists
															// (permission to drop vars in that list will be sought following
	} //endif 'cmd'											//  'genyhats' codeblock, below)
															// 'null' option signals no separate list of default-prefixed vars
	
	
	
	if "`cmd'"=="genplace"  {								// See comments under 'if 'cmd'=='gendist' above for explication

	   foreach var of local keepanything  {
		  foreach prfx in m p i  {							// Created vars will be prefixed with pm_, pp_, or pi_
		      local pfx = "p`prfx'"							// Construct corresponding variable prefix with extra "p"
			  local prfxprefix = "`prfx'prefix"				// If an option renames this prfx, substitute renamed version
		      if "`prfxprefix'"!="" local pfx = "p`prfxprefix'" 
			  local check = "`check' `pfx'_`var'"			// Add it to list of existing vars
		  }
	   } //next var											

	   isnewvar `check', prefix(null)						// Subprogram 'isnewvar' extends $exists list if var alrady exists
															// (permission to drop vars in that list will be sought following
	} //endif 'cmd'											//  'genyhats' codeblock, below)
															// 'null' option signals no separate list of default-prefixed vars
		

		
	if "`cmd'"=="genyhats"  {								// See comments under 'if 'cmd'=='gendist' above for explication

		foreach var of local keepanything  {				// Here 'prfxvar', from codeblk (2) indicates variable prefix
			if "`prfxvar'"=="" & "`multivariate'"==""  {	// If this is NOT a multivariate procedure (empty prfxvar)
				local pfx = "yi"							// So created vars will be prefixed with 'yi_'
				if "`iprefix'"!="" local pfx = "y`iprefix'"	// If 'iprefix' was optioned, replace with that string
				local check = "`check' `pfx'_`var'"			// Add it to list of vars to be checked														
												
			}	
			else  {											// Else this multivariate varlist is prefixed with depvarname
				local pfx = "yd"							// (unless user options a different prefix for multivariate)
				if "`dprefix'"!="" local pfx = y`dprefix'
				local check = "`check' `pfx'_`var'"			// Add it to list of vars to be checked														
			}
		} //next var										// (program isnewvar, below, asks for permission to replace)
		
		isnewvar `check', prefix(null)						// Check to see if relevant prefixed vars already exist
															// (and drop the prefixed vars if user responds with 'ok')
	} //endif `cmd'=='genyhats'								
		

															// Here issue any error message arising from the above checks
	if "$exists"!=""  {										// (this is list of errors found by subprogram 'isnewvar')
	
	   display as error _newline "Outcome variable(s) $exists already exist; drop these?"
	   capture window stopbox rusure "Outcome variable(s) $exists already exist; Drop these?" _newline
	   if _rc  {											// Non-zero return code tells us dropping is not ok with user
		 global exit = 2									// Set $exit==2 `cos no need to restore data before exit
		 exit 1												// (not yet changed working data from what is in 'origdta)
	   }													// (NOTE: 'exit 1' is a command that exits to the next level up)
	   else  {												// Else drop these existing vars
	   	 drop $exists
*		 global exists = ""									// This global retained to drop vars already saved in 'origdta'
	   }													// (when that is restored in codeblk (10) below)
	} //endif $exists  
	
	
	if "$badvars"!=""  {									// If there are vars w upper case prefix, maybe from prior error exit
	   display as error "Vars seemingly left from earlier error exit: $badvars ; drop these?"
	   capture window stopbox rusure "Vars seemingly left from earlier error exit: $badvars ; drop these?"
	   	 if _rc  {											// Non-zero return code tells us dropping is not ok with user
		 global exit = 1									// Set $exit==1 `cos need to restore data before exit
		 exit 1												// (might have changed working dta by dropping $exists)
	   }													// (NOTE: 'exit 1' is a command that exits to the next level up)
	   else  {												// Else drop these existing vars
	   	 drop $badvars
*		 global badvars = ""								// This global retained to drop vars already saved in 'origdta'
	   }													// (when that is restored in codeblk (10) below)

	} //endif $badvars
															// ******************************************************************
															// NOTE: Any exit before this point is a type-2 exit not needing data 
															// to be restored. There should only be type-1 exits after this
															// (these do require the full dataset to be restored)
															// ******************************************************************
		
pause (5.1)



										// (5.1) Call on '_mkcross' to enumerate all contexts identified by a single variable
										//		 that increases monotonically in increments of a single unit across contexts
			
*	**********	
	if ! $exit  {											// If NOT already had an error requiring restoration of origdta
*	**********		
		
	  tempvar _ctx_temp										// Variable will hold constant 1 if there is only one context
	  tempvar _temp_ctx										// Variable that _mkcross will fill with values 1 to N of cntxts
	  capture label drop lname								// In case error in prev stackMe command left this trailing
	  local nocntxt = 1										// Flag indicates whether there are multiple contexts or not

	  if "`contextvars'" != "" | "`stackid'" != ""  local nocntxt = 0  // Not nocntxt if either source yields multi-contxts
	  if "`contextvars'" == "" & "`cmd'"=="genplace" local nocntxt = 1 // For genplace stacks don't produce separate contxts
																	   // (so nocntxt setting depends only on `contextvars')
	  if `nocntxt'  {
		gen `_temp_ctx' = 1									// Don't need _mkcross to tell us no contextvars = no contxts
	  } 
			
	  else {												// else we do have multiple contexts
			
		local includestks = 1
		if "`cmd'"=="genplace" & "`stklevel'"==""  local includestks = 0 // If genplace, no stacks unless 'stklevel' optioned
		if `includestks'  local ctxvars = "`contextvars' `stackid'" 	 // If includestks, supply what was optiond 
		else  local ctxvars = "`contextvars'"				// For cmd `genplace', stackid must not be included 			 		***
															// (unless a 'call' is optioned for that command)
															
		local optionsP = subinstr("`optionsP'", "contextvars(`contextvars')", "", .) 
															// Substitute null str 'cos contextvars have morphed into 'ctxvars'
															// (this removes `contextvars' from `optionsP' – should not be there!)	***
															
*		****************
		quietly _mkcross `ctxvars', generate(`_temp_ctx') missing strok labelname(lname)										 		//	***
*		****************									// (generally calls for each stack within context - see above)


	  } // endelse 'nocntxt'
			
	  local ctxvar = `_temp_ctx'							// _mkcross produces sequential IDs for selected contexts
															// (NOT TO BE CONFUSED with `ctxvars' used as arg for _mkcross)
	  quietly sum `_temp_ctx'
	  local nc = r(max)										// This is the number of contexts (`c'), used below and in `cmd'P		
				
	

	
	
																																					
*	  **************										// THIS IS WHERE UNWANTED VARIABLES ARE DROPPED FROM WORKING DATA
	  keep `keepvars' `_temp_ctx'							// Keep only vars involved in generating desired results
*	  **************										// (`keepvars' was `keep' with dups removed after 'unab', codeblk 5)
					


	} //endif !$exit


					



/*																// COMMENTED OUT BECAUSE NOW DONE IN PROG checkSM, called above					
pause (5.2)

										// (5.2) Deal with vars that user has referred to as SMitem or S2item, renaming them
										//		 appropriately in the working subset


	foreach item in SMitem S2item  {
		
	   if strpos("`keepvars'", "`item'")>0	{					// If user included SMitem or S2item in varlist or option
		  local label : var label `item'						// Retrieve primary stack `itemname' (linkage variable)
		  local itemvar = word("`label'",1)						// Name of var linked to is stored in 1st word of var label
		  if "`itemvar'"!=""  {									// If `S?item' points to a unit-level linkage variable ...
			capture confirm variable "`itemname'"
			if _rc  {
			   display as error "User references variable `item', which does not link to an existing variable{txt}"
*						         12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			   window stopbox stop "`item' does not link to an existing variable; will exit on 'OK'"			
			}
			copy `itemvar' `item'								// Copy the linkage var to S?item, named by that alias name
			local keepvars = "`keepvars' `item'"				// Add the aliased variable to the list of vars to be kept
		  }
		  else  {												// AS YET NO USE MADE OF SMitem ??	
			display as error "Use option {opt itemname} to name a variable referenced by quasi-varname SMitem{txt}" 					***
*               		  	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			window stopbox stop "Use option {opt itemname} to name a variable referenced by quasi-varname SMitem; will exit on 'OK'"			
		  }	
	    } //endif 'strpos'
		
	} //next item (will be S2item)
*/	




					
pause (5.3)

										// (5.3) Here introduce data checks that should be conducted on entire dataset (it will be
										//		 reduced in next codeblk to just the data for each context. Alco call any 'cmd'O
										//		 preparatory programs, before dropping all but working data for each context
	
*	**********	
	if !$exit  {											// Only if error exit not already flagged
*`	**********



	  if "`cmd'"=="gendist"  {									// THIS SHOULD BE DONE IN gendist0									***
	  	 
		 local ismiss = 0										// By default we assume no Stata missing values (>=.)
	  	 foreach var of local outcomes  {
		 	quietly summarize `var' 
			if r(N)<_N  local ismiss = `ismiss' + 1				// SHOULD ALSO FIND A WAY TO INCLUDE prefixvar/selfplace			***
		 } //next 'var'
		 
		 local nvars = wordcount("`outcomes'")
		 if `ismiss'<`nvars'  {									// If equal then none have Stata missing values
			
		    noisily display "`ismiss' outcome vars out of `nvars' have missing observations; nonsense may result" 
*						      12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		    local msg = "`ismiss' outcome vars out of `nvars' have missing observations; nonsense may result"
		    capture window stopbox rusure "`msg' unless this is expected; click 'OK' to continue"
			if _rc  {
		 	   global exit = 1
			}
			
		 } //endif
			
	  } //endif 'gendist'


	  if "`cmd'"=="genplace"   {							// For command genplace (so long as 'call' is not optioned)
															// THIS CODEBLOCK SHOULD BE MOVED TO genplaceO							***
	    if `limitdiag'  {

		 local rmin = 0										// Initialize 'cweight' min as unproblematic
	     local outrnge = 0									// Same for mean

	     if "`cweight'"!="" {								// If cweight was optioned for 'genplace'
		
		  foreach var of local cweight {					// cweight could have several weight variables
		  
		    quietly summarize `var'							// Get actual minimum and mean for 'cweight' across all contexts
		
		    local rmin = r(min)
			local rmean = r(mean)
			local outrange = 0
		    if `rmean'<0.85 | `rmean'>1.15  local outrnge = r(mean)
		    if `rmin'<0 | `outrange' {						// If either value was changed from 0
			  local rmin = substr("`rmin'", 1, 4)			// Truncate value to what will fit in 4 characters
			  local rrange = substr("`outrnge'", 1, 4)
			  display as error "cweight minimum should be >=0 with mean close to 1; min is `rmin', mean `rrange'"
*						        12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			  capture window stopbox rusure ///
					  "cweight var minimum should be >=0 with mean close to 1; min is `rmin', mean is `outrnge'. Continue anyway?"
			  if _rc  {
				global exit = 1								
				exit 1
			  }
			  else  display as error "Execution continues ..."
			  
 		    } //endif 'rmin'
		  
		  } //next 'var'
	  
	     } //endif 'cweight'								// ABOVE CODEBLK CAN BE REMOVED TO 'genplaceO' when convenient
	  
		global varlist = "`keepanything'"					// First put varlist into global where 'cmd'P can get it
															// (needed by by some, but apparently not by 'genplaceO')
		} //endif 'limitdiag'	
	 
	  } //endif 'cmd'=='genplace'
															// (it containes only vars from multivarlst, not symbols etc. )
															
															
	  	  	
	  if "`cmd'"=="geniimpute" | "`cmd'"=="genplace"  {
	  	
		
*	 	********************
		`cmd'O `multivarlst', `optionsP' nc(`nc') /*c(`c')*/ nvarlst(`nvarlst') wtexplst(`wtexplst')
*	 	********************								// (local c does not have a value at this point)
	 
	 
	  } //endif 'cmd'
	
	
	
*	  ********	
	} //endif !$exit
*	  ********												// End if clause determining whether 'cmd'O was called
															// ('cmd'O may itself have flagged an error)														
															// Here restore origdata and exit to caller if priior error
		   	

	if $exit  {												// Any previous $exit==1 means restoring origdta then exit
*				***************
				capture restore								// Not sure what can go wrong but evidently something did
				quietly use `origdta', clear
				exit 1
*				***************

	} //endif $exit

					
					
					

					
pause (6)	
										// (6) Cycle thru each context in turn 'keep'ing, first, the variables discovered above to be
										//	   needed in the working dataset and, later, the observations, selected by any 'if' or `in'
										//	   expressions, before checking for context-specific errors. These checks include, for 
										//	   'genplace', a call on 'genplaceO' (for 'genplaceOpen') that will contain code that, for 
										//	   other commands, is included in 'cmd'P. In the next re-write other commands may be added 
										//	   to this category, starting with 'cmd's that have been divided into two or more (one part 
										//	   executed only for the 1st context).

		

	if `nc'==1  local multiCntxt = ""						// If only 1 context after ifin, make like this was intended			
															// (seemingly unused)													***
	if "`multiCntxt'"== ""  local nc = 1					// If "`multiCntxt' is empty then there is only 1 context
															// (set in `cmd'.ado)
																	  
	if substr("`multivarlst'",-2,2)=="||" {			  		// See if varlist ends with "||" (dk why this happens)
	   local len = strlen(strtrim("`multivarlst'"))
	   local multivarlst = strtrim(substr("`multivarlst'",1,`len'-2)) 
	}														// Strip those pipes if so
	
	global multivarlst = "`multivarlst'"					// Makes 'multivarlst' available to 'cmd' caller programs
															// (which are re-entered at end of wrapper)

	if `limitdiag'<0 local limitdiag = .					// Overwrite `limitdiag' with big number if =-1

	  
	  
*	********************
	forvalues c = 1/`nc'  {								 	// Cycle thru successive contexts (`c')
*	********************
	
	
	    local lbl : label lname `c'							// Get label associated by _mkcross with context `c'
															// 'cmd'P programs need to have labelname 'lname' hardwired

*		********
	    preserve								 			// Next 3 codeblks use only working subset of context `c' data
*		********

		   if "`cmd'"=="genstacks"  {						// Here initialize SMvars, where will not be kept if $exit
			  if "`stackid'"==""  {
				 qui gen SMstkid = .						// Missing obs will be filled with values generated by reshape
				 qui gen SMnstks = .						// Missing obs will be filled with values found after stacking
				 gen SMunit = _n							// Above missing-filled vars created to avoid re-ordering
				 local keepstackvars = "SMstkid SMnstks SMunit" // NOTE these vars should be kept only if referenced by user ??		***
			  }
		
			  if "`dblystkd'"!=""  {
				 qui gen S2stkid = .						// Missing obs will be filled with values generated by reshape
				 qui gen S2nstks = .						// Missing obs will be filled with values found after stacking
				 gen S2unit = _n							// Above missing-filled vars created to avoid re-ordering
				 label var S2unit "Sequential ID of observations that were units of analysis in the unstacked data"
*						           12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  }
			  local keepstackvars = "`keepstackvars' S2stkid S2nstks S2unit" // Keep in working data
			  
		   } //endif 'cmd'=='genstacks'

		
			if "`ifexp'"!="" local extifexp = "`ifexp' &"			  // If there IS an ifexp need to follow it with "&"
			else local extifexp = "if"								  // Else need the command "if" instead

					
			
*			************											  // THIS IS WHERE UNWANTED OBS ARE DROPPED FROM WORKING DATA
			quietly keep `extifexp' `c'==`_temp_ctx' `inexp'			
*			************									 		  // `tempexp' starts either with 'if' or with 'ifexp &'
				

			   
			if `limitdiag'>=`c' & "`cmd'"!="geniimpute" {		  	  // If `varmis'!="" note will be displayed after `cmd'P call																						 
																	  // (geniimpute produces its own diagnostics)
				   local vartest = "`keepanything'"					  // KEEPANYTHING SHLD ALREADY HAVE EXTRANIOUS SYMBOLS REMOVED	***	
				   if "`cmd'"=="genstacks" local vartest = "`keepimpliedvars'" 
				   local varmis = ""								  // Will be list of vars that are all-missing in this context
				   local vartest = subinstr("`vartest'","||"," ",.)   // Remove all "||", replacing with " "
				   local vartest = subinstr("`vartest'",":", " ",.)   // Remove all ":", ditto
				   if "`opt1'"!="" & "`prfxtyp'"!="var" local vartest = subinstr("`vartest'","``opt1''","",.) // Remove any 'opt1' 
				   unab vartest : `vartest'							  //  prefix strings from list of vars being tested

				   local test : list uniq vartest					  // Strip any duplicates of vars in vartest; put result in 'test'
				   local nvars = wordcount("`test'")
				   scalar minN = .									  // (a big number)
				   scalar maxN = -999999

				   foreach var of local test  {					  	  // For each var in 'vartest' (now 'test')
				   
  					  capture qui count if  ! missing(`var')		  // Should flag error if var does not exist in this context
					  if _rc!=0  {									  // If attempt leads to error
					  	 local varmis = "`varmis' `var'"	  		  // Add offending var to list of all-missing vars
					  }
					  else {										  // If no valid cases
					  	 if r(N)==0  {								  // Add offending var to same list
					  	    local varmis = "`varmis' `var'"  		  // If no obs, add to 'varmis' list 
					     }											  // NOTE MISSING 's IF ABOVE /**/ ARE REMOVED
				      } //endelse
					  
					  local i = 0
					  local noobsvarlst =""
					  
					  while `i'<`nvars'  {							  // Cycle thru 'nvars' variables
						local i = `i' + 1
						local var = word("`test'",`i')
						tempvar mis`var'
						qui gen `mis`var'' = missing(`var')			  // Code mis'var' =0, or =1 if missing
						qui capture count if ! `mis`var''			  // Unless errer, yields r(N)==0 if var does not exist
						local rc = _rc								  // Place command in left margin because of how it prints
if `rc' display `rc'
					    if `rc' & `rc'!=2000  {						  // If non-zero return code which is not 'no obs'
							global exit = 1							  // use $exit=1 'cos we must restore origdata before exit
							continue, break							  //  origdta before exiting (NOTE $exit=1 is not 'exit 1')
						}
						local rN = r(N)
						if `rN'==0  {								  // If there are no non-miss obs for this var in this context
						   local noobsvarlst = "`noobsvarlst' `var'"  // Store any vars with no obs 
						}
						else {										  // Else, if vars were not flagged as all-missing
						   if `rN'<minN  scalar minN = `rN'		  	  // Update min and max scalar values
						   if `rN'>maxN  scalar maxN = `rN'
						}
						quietly drop `mis`var''
					  } //next while
					  
					  if $exit  continue, break

				   } //next var
				   
				   if !$exit  {								  		  // Only execute this codeblk if an error has not called for exit 
				      if `rc'!=0 & `rc'!=2000 {						  // If there was a diffrnt error in any 'count' command
						 local lbl : label lname `c'				  // Get the context id
					     display as error "Stata has flagged error `rc' in context `lbl'{txt}" _continue
error `rc'
					     global exit = 1							  // Set flag for wrapper to exit after restoring origdata
				      }
				   
				   } //endif !$exit
			 
		   } //endif 'limitdiag'
				 

				 
		   if  !$exit  {											  // Only execute this codeblk if an error has not called for exit 

	         forvalues nvl = 1/`nvarlst'  {							  // HERE ENSURE WEIGHT EXPRESSIONS GIVE VALID RESULTS				***
	   				 
		       if "`wtexplst"!=""  {								  // Now see if weight expression is not empty in this context

			     local wtexpw = word("`wtexplst'",`nvl')			  // Obtain local name from list to address Stata naming problem
				 if "`wtexpw'"=="null"  local wtexpw = ""
				 
				 if "`wtexpw'"!=""  {								  // If 'wtexp' is not empty
				   local wtexp = subinstr("`wtexpw'","$"," ",.)		  // Replace all "$" with " "
																	  // (put there so 'words' in the 'wtexp' wouldn't contain spaces)
				 
*				   *********************							  // [ COMMENTED OUT 'COS NOW ATTEMPTING TO IDENTIFY ACTUAL WTVARS ]
			       capture sum `origunit' `wtexp', meanonly		      // Weight the only var known to exist in a call on `'summarise'
*				   *********************

			       if _rc  {										  // An error can only be due to the 'weight' expression

				     if _rc==2000  display as error "Stata reports 'no obs' error; perhaps weight var is missing in context `lbl' ?{txt}"
				     else  {
					   local l = _rc
					   display as error "Stata reports error `l' in context `lbl'{txt}"
				     }
error `l'
			         global exit = 1								  // Tells wrapper to exit after restoring origdata
				     continue, break								  // Must restore origdta before exiting
																	  // (must break out of loop before restoring)
			       } //endif _rc

		         } //endif `wtexpw'
				 
			   } //endif `wtrxplst'
			 
		     } //next 'nvl'
		   
		   } //endif !$exit
		   
		   
		   
		   if $exit  {											 	  // Any previous $exit==1 means restoring origdta then exit
*				***************
				capture restore										  // Not sure what can go wrong but evidently something did
				quietly use `origdta', clear
				exit 1
*				***************

		   } //endif !$exit


		   
		   
		   if "`cmd'"=="genstacks'" local  multivarlst = "`stublist'" // Genstacks processes stubnames, not varnames
		   global multivarlst = "`multivarlst'"					 	  // Global version accessible to calling prog in `cmd'.ado  


		   
					
		
			
			
			   
pause (7.1)



										// (7.1) Issue call on `cmd'O (for 'cmd'Open). In this version of stackmeWrapper the
										//		 call occurs only for command 'genplace' but additional commands may have their
										//		 opening codeblocks transferred to this codeblk in future releases of staclMe.
										// 		 See opening comments of codeblk 6 for additional details.
										//		 NOTE THAT WE ARE STILL USING THE WORKING DATA FOR A SPECIFIC CONTEXT `c'
										//		 (IF NOT STILL SUBJECT TO AN EARLIER IF !$exit CONDITION)


		

		
		   
		   if "`cmd'"=="genplace"  {								// NOTE that preparatry `genplaceO' was called in codeblk 5.2
		   

*				********************
				`cmd'P1 `multivarlst', `optionsP' lbl(`lbl') nc(`nc') c(`c') nvarlst(`nvarlst') wtexplst(`wtexplst')
				`cmd'P2 `multivarlst', `optionsP' lbl(`lbl') nc(`nc') c(`c') nvarlst(`nvarlst') wtexplst(`wtexplst')
*				********************								// Code in these two commands needs to be re-arranged
																	// (so that `cmd'P1 calls P2 once for each varlist in mu)
		   } //endif `cmd=='genplace'
			


		  if $exit  {											 	// Any previous $exit==1 means restoring origdta then exit
*				***************
				capture restore										// Not sure what can go wrong but evidently something did
				quietly use `origdta', clear
				exit 1
*				***************

		  } //endif !$exit
			
			
			



pause (7.2)



										// (7.2) Issue call on `cmd'P with appropriate arguments; catch any `cmd'P errors; display 
										//		 optioned context-specific diagnostics
										//		 NOTE THAT WE ARE STILL USING THE WORKING DATA FOR A SPECIFIC CONTEXT `c'
										//		 (IF NOT STILL SUBJECT TO AN EARLIER IF !$exit CONDITION)

set tracedepth 5																		
		   
		   
		
				
		  if "`cmd'"!="genplace"  {										// genplace needs tailored call, above
																		// (other cmds after revision)
																		
*				 **************				     	 					// Most `cmd'P programs must be aware of lname for ctxvars  ***
				`cmd'P `multivarlst', `optionsP' nc(`nc') c(`c') nvarlst(`nvarlst') wtexplst(`wtexplst')
*				 **************											// `nvarlst' counts the numbr of varlsts transmittd to cmdP


		  } //endif 'cmd'!="genplace"

			  
		  if $exit  {											 		// Any previous $exit==1 means restoring origdta then exit
*				***************
				capture restore											// Not sure what can go wrong but evidently something did
				quietly use `origdta', clear
				exit 1
*				***************

		  } //endif !$exit
			  
	
	
	
					
		  if `limitdiag'>=`c'  {										// `c' is updated for each different stack & context
								   
						
					  local numobs = _N
				   	
					  local contextlabel : label lname `c'				// Get label for this combination of contexts
					  
					  local contextlabel = "Context `contextlabel'"		// Below we expand what will be displayed
																		// (depending on context)
					  if `c'==1 noisily display "{bf} "
					  
					  local newline = "_newline"
					  if "`cmd'"=="genstacks" local newline = ""
					  
					  if "`multiCntxt'"=="" {
					  	 local contextlabel = "{bf}This dataset"
						 noisily display "{bf}   `contextlabel' has `numobs' cases{txt}" _newline
					  }
					  
					  if "cmd'"=="genstacks"  local contextlabel = "This dataset now"

					  if "`multiCntxt'"!="" & "`cmd'"!="geniimpute" {	// Geniimpute has its own diagnostics  WHY NOT geniimpute?		***
					  	 if "`cmd'"=="gendiimpute'" noisily display "{bf}   `contextlabel' has `numobs' cases{txt}" 
						 if "`cmd'"=="gendist"      noisily display "{bf}   `contextlabel' has `numobs' cases{txt}" 
						 else 						noisily display "{bf}   `contextlabel' has `numobs' cases{txt}" 
					  }													// See which format to choose for each 'cmd'
					  
					  local lbl : label lname `c'
					  local lbl = "context `lbl'"						// Expand what will be displayed
						 
					  if "`multiCntxt'"==""  local lbl = "this dataset" // Depending on context
						
					  local other = "Relevant vars "					// Resulting re-labeling occurs with next display
					  if "`noobsvarlst'"!=""  {
				   	      noisily display "{...}{p}{bf}No observations in `lbl' for vars: `noobsvarlst'{...}{p_end}{txt}" _continue
						  local other = "Other vars "					// Ditto
					  }
					  if "`cmd'"!="geniimpute"  {						// 'geniimpute' displays its own diagnostics
						  local minN = minN								// Make local copy of scalar minN
						  local maxN = maxN								// Ditto for maxN
						  local lbl : label lname `c'
						  local newline = "_newline"
						  if "`cmd'"=="genstacks" local newline = ""
						  if "`multiCntxt'"!="" & "`cmd'"!="geniimpute" noisily display /// geniimpute displays its own diagnostics
								"{bf}`other'in context `lbl' have between `minN' and `maxN' valid obs{txt}" _newline
					  } //endif
					
					  noisily display "{txt}" _continue
						 
						 
		  } //endif 'limitdiag'

				   

						
		  if "`cmd'"!="geniimpute"	 {									// 'geniimpute' displays its own diagnostics
		  
		     if `limitdiag'>=`c' & "`varmis'"!="" {						// `varmis' got its value before call on `cmd'P

*				if "`extradiag'"!=""  {									// SHOULD THIS BE PRINTED EVEN IF NO EXTRADIAG OPTD?		***
				  if `limitdiag'  {
				    local errtxt = ""
					local nwrds = wordcount("`varmis'")
					local word1 = word("`varmis'", 1)
					local word1 = ``word1''								// Replace word1 with the var word1 points to
					if `nwrds'>2  {						
					   local word2 = word("`varmis'", 2)				// Replace word2 with the var word2 points to
					   local word2 = ``word2''
					}
					local wordl = word("`varmis'", -1)					// Last word is numbered -1 ('worl' ends w lower L)
					local wordl = ``wordl''								// Replace wordl with the var wordl points to
					if `nwrds'>2  local errtxt = "`word2'...`wordl"
					if `nwrds'==2 local errtxt = "`word1 `wordl'"
					if `nc'==1 display as error "{bf}NOTE: No observations for var(s) `word1' `errtxt' in context `lbl'{txt}"
					if `nc'>1  display as error "{bf}NOTE: No observations for var(s) `word1' `errtxt' in context `lbl'{txt}"
				  } //endif extradiag										// `limit' is from `limitdiag' before above "forvalues `c'="

			 } // endif `limitdiag'


			 else  {														// If limitdiag IS in effect, print busy-dots
		  
				if "`multiCntxt'"!= ""  {									// If there ARE multiple contexts (ie not gendummies)
					if `nc'<38  noisily display ".." _continue				// (more if # of contexts is less)
					else  noisily display "." _continue						// Halve the N of busy-dots if would more than fill a line
				}
			 
			 } //endelse
			 
		  } //endif 'cmd'!='geniimpute'	
	     

					 
					 
					 
pause (8)
				
								// (8)	Here we save each context in a tempfile for merging once all contexts have been processed.
								//		This means recording a filename for each context*stack in a list of filenames whose length
								//	is limited by the maximum length of a Stata macro (on my machine 645,200 bytes.) So the first
								//	time a dataset is processed we need to check on the max for that machine, find the length of
								//	the tempname (the string following the final / or \) and see if the product of contexts*stacks
								//	is less. If not we must start another list that will ultimately be appended to previous lists.
								//  NOTE THAT WE ARE STILL USING THE WORKING DATA FOR A SPECIFIC CONTEXT `c'
			
			
	
	
		  tempfile i_`c'											// We need one of these files for each context/stack
		  quietly save `i_`c''										// Here create tempfile for 1st context, named "i_`c'"	
		  local fullname = c(filename)								// Path+name of latest datafile used or saved by any Stata cmd
	 	  local namloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Posn of first char following final "/" or "\" of directory path
		  local thisname = substr("`fullname'",`namloc',.)			// Trailing name of file to hold data generatd for this context
		  local namlen = strlen("`thisname'")						// (may be more than 1) Get length of string holding filename
	
		  if `c'==1  {												// If this is 1st contxt; create base file onto which to append

			global temp = "`i_`c''"									// Save this name in accessible global (append the remainder)
		    global savepath = substr("`fullname'",1,`namloc'-1)		// Path to final dirsep should be same for all successive files
																	// (path ends with dirsep – "/" or "\")
			local listlen2 = 0										// N of names in first list of files to be appended (none as yet)
			local appendlst2 = ""									// Local holds 1st list of tempfile names (ends with dirsep)
			local nlst = 2											// Number of current list used to store tempfile names (more
*		    local nname = 0											// Position of 'thisname' in this list of filenames
			local nnames2 = 0										// Local nnames`nlst' used to record length of a full nameslist
			
		  } //endif `c'==1
			
		  else {													// Else this is a file that will ultimately be appended to $temp
			
			   
			 if `listlen`nlst''+`namlen' > c(macrolen)  {			// If incr lenth of current list of names would be > c(macrolen)
			      local nnames`nlst' = `nname'						// Store n of names in this full list hefore starting next list
*				  local nname = 0									// Position of first name in the new list will be incrementd below
				  local nlst = `nlst' + 1							// lst (so increment n of lists holding these names; reset `name#')
				  local nnames`nlst' = 0							// For each filename list this holds the N of names in that list
				  local listlen`nlst' = 0							// Zero the accumulated length of next namelist
				  local appendlst`nlst' = ""						// Empty the next list of tempfile names
			 }
			   
			local listlen`nlst' = `listlen`nlst'' + `namlen' + 1	// Need enough space to list filenames of all doubly-stacked files
			local appendlst`nlst' = "`appendlst`nlst'' `thisname'" 	// and appends it to current list (after a space)
			local nnames`nlst' = `nnames`nlst'' + 1					// Store the position of the this name within this list
		
		  } //endelse
						
	   
*		*******
		restore														// Here finish with working data, briefly restore full dataset
*		*******														// (briefly unless this is the final context or error exit)
			
		if $exit continue, break									// Should not occur: any errors should have led to earlier exit
	   
	   
*	**********************
	} //next context (`c')											// Repeat while there are any more contexts to be processed
*	**********************
	

	
	
pause (9)	

	
										// (9) After processing last contxt (codeblk 6), post-process generatd data for mergng w original
										//	   (saved) data. NOTE THAT THE DATA BEING PROCESSED IS NO LONGER THE WORKING DATA SUBSET
										
*describe using $temp, simple

	
	quietly use $temp, clear										// Open the file onto which, if multicntxt, more will be appended

	if "`multiCntxt'"!= ""  {										// If there ARE multi-contexts (local is not empty) ...
																	// Collect up & append files saved for each contxt in codeblk (8)
																	// (If there was only one context then just one was saved)
		preserve													// Need to preserve again so as to append contexts to $temp file

			local nlst = 2											// Start with the first list out of the possible set of lists
			local nname = 1											// Number (position) of this name in this list
		   
			forvalues i = 2/`nc'  {									// Cycle thru all contexts whose filenames need to be appended

*				local temp = nnames`nlst'							// Trying to avoids error reading `nnames`nlst''
				if `nname'>`nnames`nlst''  {						// If 'nname' is beyond nnames saved for this list in codeblk (8)
					local nlst = `nlst' + 1							// (so increment n of lists holding these names; reset `name#')
					local nname = 1									// The next tempfile will hold the first remaining context name
				}
	
*				local temp = "appendlst`nlst'"
				local a = word("`appendlst`nlst''",`nname')			// Get name of this file in `appendlst`nlst''; append context
				quietly append using $savepath`a', nonotes nolabel 	//  data to $temp file using directory path to that contxt name
				erase $savepath`a'									// Erase that tempfile	($savepath ends in `dirsep')
				
				local nname = `nname' + 1							// Increment the position of next filename in this list
				 
			} //next 'i'
																			
			quietly save $temp, replace								// File `temp' now contains all new variables from `cmd'P
		
		restore
		
	
	} //endif `multiCntxt'											// If not a multicontext dataset the one file is all there is
	  
	
	
	

pause (10)
	
										// (10) Restore previous names of variables temporarily renamed to avoid naming conflicts; 
										//		merge new vars, created in `cmd'P, with original data

										
	quietly use `origdta', clear							// Retrieve original data to merge with new vars from `cmd'P
	
	if "$exists"!=""  {										// This is list produced by subprogram 'isnewvar' in codeblk (5)
															// (dropped from working data in (5) now must be dropped from origdta)
	   	 drop $exists
		 global exists = ""									// (and empty the global)
	   
	} //endif $exists  
	
	
	if "$badvars"!=""  {									// If there are vars w upper case prefix, maybe from prior error exit
	
	   	 drop $badvars
		 global badvars = ""								// (and empty the global)

	} //endif $badvars

/*															// THIS NEXT BLOCK MAY BE REDUNDANT AFTER ADDING CODE ABOVE				***
	if "$prefixedvars"!=""	{								// If there were any name conflicts for merging
															// (diagnosed before call on 'cmd'P)
	  foreach var of global prefixedvars  {					// This global was filled as a bi-product of codeblock (5) 
	    local prfx = strupper(substr("`var'",1,2))			// Change prefix string to upper case (it is followd by "_")
	    local tempvar = "`prfx'" + substr("`var'",3,.)		// All prefixes are 2 chars long and all were lower case
		capture confirm variable `tempvar' 					// If it already exists we had the same conflict earlier
		if _rc==0  drop `tempvar'							// (the prefix is capitalized so var can be dropped w'out harm)
	    rename `var' `tempvar'								// Each 'var' has a "_" in 3rd character
	  } //next prefixedvar

	} //endif $prefixedvars
*/	  

	  
*	*****************	  
	quietly merge 1:m `origunit' using $temp, nogen update replace
*	*****************												// Here the full temp file is merged back into `origdta'
				
		
		
	capture erase `origdta'									   		// Erase tempfile and drop origunit
	capture erase $temp
	capture drop `origunit' 
	global temp = ""
	global savepath = ""
	global namelen = ""
	global numnames = ""
	global exists = ""												// Ditto, for list of vars with revised prefixes if optioned

	

	
end //stackmeWrapper





**************************************************** SUBROUTINES **********************************************************




capture program drop errexit

program define errexit


	args msg stataerror							// First arg is msg to display; 2nd is code producing Stata error, if any
	
	display as error "`msg'"
	
	if "`stataerror'"!=""  {
		
		window stopbox note "`msg'; supplementary Stata message on 'OK'"
		unab error : `stataerror'
		
	} //else
	
	window stopbox stop "`msg'; will exit $cmd on 'OK''"
	
	
end errexit





capture program drop checkSM					// SHOULD MAYBE BE SPLIT INTO chkvars AND chkSM							***
		
program define checkSM, rclass					// Checks for valid vars and any SM vars. Partially overcomes problem
												// that Stata cannot accumulate list of invalid varnames

	args check													// Contains list of non-'unab'ed variables	
	
		local check : list uniq check							// Remove any duplicates; then check validity
																//				   of each var and hyphenated varlist 
		local errlst = ""										// List of invalid vars and invalid hyphenatd varlsts
		local strerr = ""										// (first) bad hyphenated varlist
		
		local check = strtrim(stritrim("`check'"))				// Eliminate extra blanks around or within 'check'
		
		if strpos("`check'","-")==0  {							// If there are no hyphenated varlists
		
			foreach var of local check  {
				capture confirm variable `var'					// If 0 not returned
				if _rc  local errlst = "`errlst' var"			// Add any invalid vars to 'errlst'
			}
		}
		
		else  {													// Else there are one or more abbreviated varlists
		
		  local chklist = "`check'"								// Want to keep 'check' untouched for SM search, below
																
		  while strpos("`chklist'","-") >0  {					// While there is an(other) unexpanded varlist in 'chklist'
		  
			local loc = strpos("`chklist'","-")					// Find loc of hyphen that defines the list
			local head = substr("`chklist'",1,`loc'-1) 			// Extract string preceeding hyphen
			local test1 = word("`head'",-1)						// Extract last word in 'head' (word before hyphen)
			local tail = substr("`chklist'",`loc'+1,.)			// Extract string following hyphen
			local test2 = word("`tail'",1)						// Extract the 1-word varname following the hyphen
			
			local t1loc = strpos("`chklist'","`test1'")			// Get loc of first word in hypnenated abbreviation
			if `t1loc'>1  {										// If there are vars before 'test1', evaluate those
			   local pret1 = substr("`chklist'",1,`t1loc'-1)	// These vars end before 'test1'; put them in 'pret1'
			   foreach var of local pret1  {					// And evaluate each one
			   	  capture confirm variable `var'				// If 0 not returned
				  if _rc  local errlst = "`errlst' `var"		// Add any invalid varnames to 'errlst'
			   }
			}													// 'test3' will be string "'test1'-'test2'" inclusive
			local t3len = strlen("`test1'")+strlen("`test2'")+1	// Get full length of string 'test1' to end of `test2'
			local test3 = substr("`chklist'",`t1loc',`t3len') 	// String them together as when embedded in 'chklist'
			
			capture unab varlst : `test3'
			if _rc  {											// If 0 not returned ..
			  local errlst = "`errlst' `test3'"					// Add the abbreviated varlist to 'errlst'
			  if "`strerr'"==""  local strerr = "`test3'"		// (and store that varlist for Stata to identify)
			}													// If did not exit, that was a valid varlist
			
			local chklist = substr("`chklist'",`t1loc'+`t3len'+1,.) // Strip all up to end of 'test3' from head of chklist
			
			if strpos("`chklist'","-")>0 continue				// If there is another "-" skip rest of while loop 
																// (this would mean processing next segment as above)
	
			if "`chklist'"!="" {								// Else if there are more vars in 'chklist'
			   foreach var of local chklist  {					// Check that each of them is valid
			   	 capture confirm variable `var'
				 if _rc  local errlst = "`errlst' `var'"		// If 0 not returned add any invalid vars to 'errlst'
			   }
			}
			
			continue, break										// Break out of while loop

		  } //next hyphen										// See if there are any more hyphens
		  
		} //endelse
		
								
		if "`errlst'"!=""  {
			errexit "Invalid variable name(s): `errvars'" "`strerr'"
		}														  // 'errexit' will exit w msg and optional Stata msg
																  // (Stata msg producd by tryng to unab 'strerr' if any)
		return local check `check'
		
																  // Move on to possible SM vars saved in 'check'
		capture unab check : `check'
		
		local gotSMvars = ""									  // List of extant SM/S2 items
		local SMvars = ""										  // List of SMitem or S2item included  in 'check'
		local SMerrs = ""										  // SM/S2 items with no link to existing var ditto
		local SMbadlnk = ""										  // SM/S2 items whose link does not exist ditto
		local errlst = ""										  // List of broken links (linked vars that don't exist)
		
		if strpos("`check'", "SMitem")>0  local SMvars = "SMitem" // Check the same vars as checked above (inputs + outcomes)
		if strpos("`check'", "S2item")>0  local SMvars = "`SMvars' S2item" // (to see if user included SMitem or S2item)
	  
		foreach var of local SMvars  {							  // Cycle thru the (up to) 2 vars in 'SMvars'
	  	
		   local SMitem = "`_dta[`var']'" 						  // Retrieve associated linkage variable from characteristc
		   
		   if "`SMitem'" ==""  {								  // If there is no associated characteristic
			  local SMerrs = "`SMerrs' `var'"					  // Extend list of unlinked SMvars
		   }
		   else  local gotSMvars = "`gotSMvars' `SMitem'"		  // List of vars that SMvars are linked to
		   
		} //mext 'var'
		
		if "`SMerrs'"!=""  {									  // If there are any unlinked SMvars
		
		   display as error "Quasi-var(s) without active link(s) to (existing) variable(s): `SMerrs'"
*					         12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   if wordcount("`SMerrs'") == 1  {  
			  window stopbox stop "stackMe quasi-var `SMerrs' has no active link to an existing variable; will exit on 'OK'"
		   }													  // Else we have two vars without active links
		   else window stopbox stop "stackMe quasi-vars (`SMerrs') have no active links to existing vars; will exit on 'OK'"
		   
																  // If we reach this point we have links to check
		   foreach var of local gotSMvars	{					  // Cycle thru (up to) 2 vars in 'gotSMvars'
		      capture confirm variable `var'		  			  // See if these linked vars exist
			  if _rc  {											  // If link does not access an existing variable
			  	 local SMbadlnk = "`SMbadlnk' `var'"			  // Add that quasi-var to 'SMbadlnk'
			  }
		   } //next 'var'
		   
		   if "`SMbadlnk'"!="" {								  // If 'SMnolnk' is not empty
			  errexit "Quasi-vars with broken links (linked vars don't exist): `SMbadlnk'"
		   }													  // 'errexit' is a subprogram listed towards end of ado file
		}

		
		return local gotSMvars `gotSMvars'
		
		
														
end checkSM






capture program drop appendfiles

program define appendfiles

	args appendlst savpath
	
	quietly use $temp, clear								// Tempfile in which earlier context outputs were savd in (7,8)

	
	local napp = wordcount("`appendlst'")					// N of contexts appended to empty tempfile
	
	forvalues i = 1/`napp'  {				
	   local a = word("`appendlst'",`i')					// Get trailing name for each file to be appended
	   quietly append using "`savpath'`c(dirsep)'`a'", nonotes nolabel
	   erase `savpath'`c(dirsep)'`a'						// (full name of file to be appended starts with path and dirsep)	
	} //next 'i'
															// Now append the last
	quietly append using "`savpath'`c(dirsep)'`a'", nonotes nolabel
	

end appendfiles	







capture program drop varsImpliedByStubs

program define varsImpliedByStubs, rclass

	syntax namelist(name=keep)
	
	local keepv = ""											// Will hold list of vars implied by all stubnames in keep 

	while "`keep'"!=""  {										// We know that `keep' was filled with stubs by caller 
		gettoken k keep : keep									// Repeatedly peel off first word of `keep'
		unab vars : `k'*  										// Get implied varnames that starts with `nxt'
		local keepw = ""										// Enable access to locals across nested while loops 
																// (by having one local for each loop)
		while "`vars'"!=""  {
			gettoken v vars : vars, quotes 						// Peel off head of list and store w'out surrounding quotes
			local s = "`v'"										// Basis for the stub remaining when numeric suffix is gone
			local len = strlen("`v'")
			while real(substr("`s'",-1,1))<.  {					// While last char is numeric (real version is not missing)
				local len = `len' - 1
				local s = substr("`v'",1,`len') 				// Shorten `v' by one trailing numeral
			}													// (on exiting from this loop we have only a stub in `s')
			
			if "`s'"!="`k'"  continue, break					// Continue with next stub if this implied stub is not `k'
			
			local keepw ="`keepw' `v'" 							// Append this version of nxtvar to keepw (it has new stub)				
		}														// (nxtvar matches next stub if it belongs to same battery)
		local keepv = "`keepv' `keepw'"							// Seemingly keepv does not update between while loops

	} //next while												// (`keepv' lists vars to be kept, not vars to be processed)

	return local keepv `keepv'
	

end //varsImpliedByStubs







capture program drop stubsImpliedByVars

program define stubsImpliedByVars, rclass

*set trace on

	syntax namelist(name=keep)
	
	local stubslist = ""										// List will hold suffix-free copy of `keep'
				
	while "`keep'"!=""  {
		gettoken s keep : keep
		while real(substr("`s'",-1,1))<.  {						// While last char is numeric
			local s = substr("`s'",1,strlen("`s'")-1)  			// Shorten `s' by one trailing numeral
		}
		local stubslist = "`stubslist' `s'"						// `stubslist' is copy of keep, but shorn of suffixes
	} //next `keep'
				  
	local stubs = ""											// Will hold list of unique stubs from stubslist
				  
	local w1 = word("`stubslist'",1)

	while "`stubslist'"!=""	{									// So long as there are any stubs left in stubslist ...
		while "`w1'" == word("`stubslist'",1)  {				// While next word in `stubslist' remains the same ...
			gettoken w1 stubslist : stubslist					// Move successive stubs into `w1'							
		} 														// Exit this loop when `stubslist' has no more w1 stubs
		local stubs = "`stubs' `w1'"	 						// Append final copy of `w1' to list of stubs
		if "`stubslist'"!="" local w1=word("`stubslist'",1) 	// Move on to next stub, if any						
																// (need to save in a local that will persist otside loop)
	} //next while "`stubslist'"								// Exit this loop when `stubslist' has no more stubs
	
	return local stubs `stubs'

																	
end //stubsImpliedByVars





	
	

capture program drop isnewvar								// Now called from wrapper (NO LONGER CALLED FROM gendist in VERSION 2)

program isnewvar											// New vars all have prefixes 

	version 9.0
	syntax anything, prefix(string)
	
	if "`prefix'"=="null"  local prefix = ""				// No prefix will be prepended to anything-var if prefix is "null"
	
	local ncheck : list sizeof anything						// 'anything' may have several varnames
	
	forvalues i = 1/`ncheck'  {								// anything already has default prefix for each var
	
	  local var = word("`anything'",`i')
	  capture confirm variable `var'						// These vars are default-prefixed; optional changes not yet made
	  if _rc==0  {											
	    global prefixedvars = "$prefixedvars `var'"			// Add to global without revising prefix to optioned prefixstring
		if "`prefix'"!="" 	{								// If a different prefix was optioned ..
		  local prfxlessVar = substr("`var'",3,.)			// Strip off all before "_"
		  global exists = "$exists `prefix'`prfxlessVar'"	// Prepend optioned prefix and add to list of $existing vars
		}
		else  global exists = "$exists `var'"				// Add previous version to that list
	  }
	  local prfx = strupper(substr("`var'",1,2))			// Extract prefix from head of 'var' & change to upper case
	  local badvar = "`prfx'"+substr("`var'",3,.)
	  capture confirm variable `badvar'						// See if uppercase version is left over from previous error exit
	  if _rc==0  {
	  	global badvars = "$badvars `badvar'"				// If so, add to list of such vars
	  }
	  
	} //next var
		
	
end //isnewvar







capture program drop getwtvars

program define getwtvars, rclass
										// Identify and save weight variable, if present, to be kept in working dta
	args wtexp
										
		if "`wtexp'"!="" {										// If a weight variable was optioned
			
		  gettoken preeq posteq : wtexp, parse("=")				// First parse on the = as any wtvar must follow that
		  if "`posteq'"!=""  {									// (it may occupy whole of `wtexp' or the start or the end)
			local len = strlen("`posteq'") - 2					// Length of about-to-be created `wtstr', less 2 chars...
			local wtstr = strtrim(substr("`posteq'", 2,`len'))	// Remove "= " and "]" from `posteq' yielding `wtstr'
		  }														// (with possible trailing ")" )
		  
		  local wtvar1 = ""										// Define empty string into which to accumulate `wtvar' char by char
		  local lstchr = strrpos("`wtstr'", ")" ) - 1			// (we use a global because the equivalent local gets overwritten)
		  if `lstchr'==-1 local lstchr = strlen("`wtstr'")		// If no close paren, substitute final char in `wtstr'
		  forvalues i = `lstchr'(-1) 1  {						// Count backwards towards the start of `wtvar'
			local char = substr("`wtstr'",`i',1)				// Put this character in 'char'
			if indexnot("`char'", "+-*/^()" )  {				// If this char is not an operator..				
			  local wtvar1 = "`char'`wtvar1'"					// Prepend it to front of `wtvar'
			}
			else continue, break								// Else break out of the 'forvalues' loop	
		  } //next `i'
		  capture confirm numeric variable `wtvar1'				// Confirm that found string is a varname
		  if !_rc  {											// If so,..
		  	local keepv = "`wtvar1'"							// Place in list of variables to be returned
		  }
*		  local savekeep = "`keep'"

		  local wtvar2 = ""										// Empty `wtvar2' for use in next attempt to find a 'wtvar', below
		  local len = strlen("`wtstr'")
		  if substr("`wtstr'",1,1)=="(" local istchr = 2		// The weight-string might start with open parenthesis...
		  else  local istchr = 1								// If so, look for `wtvar' one char later
		  forvalues i = `istchr'/`len'  {						// Count forwards towards the end of `wtvar'
			local char = substr("`wtstr'",`i',1)				// Put next character in 'char'
			if indexnot("`char'", "0123456789+-*/^()" )  {		// If this char is not an operator or numeric char...				
			  local wtvar = "`wtvar2'`char'"					// Append it to the end of `wtvar'
			}
			else continue, break								// Else break out of the forvalues loop	
		  } //next `i'	  	
		
		  if "`wtvar2'"!=""  {
			capture confirm numeric variable `wtvar2'			// Confirm that found string is a varname
			if !_rc  {											// If so,..
				local keepv=strtrim("`keepv' `wtvar2'") 		// Add it to list of variables to be kept in working data
			}
		  }
		  
		  if "`wtvar1' `wtvar2'"==" "  {
		  	display as error "Clarify weight expression: use (perhaps parenthesized) varname at start or end{txt}"
*                		  	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			window stopbox stop "Clarify weight expression: use (perhaps parenthesized) varname at start or end; exiting on 'OK'"
		  }
		  
		} //endif 'wtexp'
		
		return local wtvars `keepv'

		
end getwtvars





capture program drop createactiveCopy						// APPARENTLY NO LONGER CALLED FROM gendist VERSION 2

program define createactiveCopy
	version 9.0
	syntax varlist, type(string) plugPrefx(name)
	capture drop `plugPrefx'`varlist'				       // Presumably `varlist' is actually `varname'
	quietly clonevar `plugPrefx'`varlist' = `varlist' 	   // Plugged copy initially includes valid + missing data
	local varlab : variable label `varlist'	
	local newlab = "`type'-MEAN-PLGD " + "`varlab'" 	   // `type' is type of missing treatment
	quietly label variable `plugPrefx'`varlist' "`newlab'" // In practice, syntax changes `plugPrefx' to `plugPrefx'

end //createActive copy








capture program drop subinoptarg

program define subinoptarg, rclass					// Program to remove supposed vars from varlist if they prove to be strings
													// or for other reasons

syntax , options(string) optname(string) newarg(string) ok(string)

set trace on
	local l = strpos("`options'","`optname'") 					// Find position of option-name in string to be amended
	if `l'>0  {													// If it is present in `options'
		local oldopt = substr("`options'",`l',.)				// extract the string bounded by start of option-name and end
		local m = strpos("`oldopt'", ")" )						// (option's argument ends withn next close parentheses)
		local oldopt = substr("`oldopt'", 1, `m' )  			// Substitute an `optstr' that holds just the optname & argument
		local subinstr("`options'","`oldopt'" ,"" ,1) 	 		// Substitute a null string for the `optstr' that is to be changed
		if "`newarg'"!=""	{									// If text for new argument was supplied
		   local options = substr("`options,'",1,`l'-1) + 	   /// Concatenate pre-option string + new option + post-option string 
			"`optname'(`newarg')"+substr("`options'",`l',.) 	// `newarg' will consist of optname + `newarg' in parentheses
		}													
	}
	else  {
		if "`ok'"==""  window stopbox stop "optname not found"	// Programming error
	}
	return local options `options'


end subinoptarg






capture program drop errmsg										// NOT DEBUGGED


program define errmsg, rclass

set trace on

	syntax , msg(string)										// GET 'varlist not allowed' ERROR (DK WHY)

	local cmdname = strpos("`msg'","`cmd'")

	local stopmsg = "`msg'"

	subinstr("`stopmsg'", "`cmd'", "command",1)
	
	display as error "`msg'"
	
	window stopbox stop "`stopmsg'"

end errmsg




************************************************ END SUBROUTINES *****************************************************


/*
local varstubs = "var1||var2"
gettoken anything varstubs : varstubs, parse("||")
display "`anything' `varstubs' : `varstubs'"

local anything = "var1 var2"
gettoken precolon tail: anything, parse(":")			// If this segment of varstubs starts with a prefixed var(list) ..
if "`tail'"!=""  local anything = substr("`tail'",2,.)	// If 'tail' is not empty, it has a colon followed by var(list)
display "`precolon' : 'anything'"
*/
