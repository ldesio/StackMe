

capture program drop stackmeWrapper

*!  This ado file is called from each stackMe command-specific caller program and contains program 'stackmeWrapper' that 'forwards' 
*!  calls on to `cmd'O and `cmd'P subprograms, where `cmd' names a stackMe command. This wrapper program also calls on various 
*!  subprograms, such as 'varsImpliedByStubs' 'checkvars' and 'errexit', whose code follows the code for stackmeWrapper. Additional
*!  cognate subprograms can be found in an ado file named 'stackMe.ado'. Two of these ('SMcontextvars' and 'SMitemvars) can be
*!  directly invoked by users.

*!  Version 4 replicates normal Stata syntax on every varlist of a v.2 commnd (eliminates previous cumulatn of opts across varlsts)
*!  Version 5 simplifies version 4 by limiting positioning of ifin expressions to 1st varlist and options to last varlist
*!  Version 6 impliments 'SMcontextvars' and the experimental movement of all preliminary 'genplace' code to genplaceO
*!  Version 7 revives code from Version 3 that tried to identify the actual variable(s) employed in a weight expression
*!  Version 8 moves additional code to new 'cmd'O programs that contain 'opening' code for gendist, geniimpute, and genstacks.
*!  Version 9 added draft genplace0 code and global varlist, prfxvar & prfxstr so `cmd'P need not do so; also simpler append code.
*!			  (simpler append code uses file with accumulating contexts and appends file with current context – turns out slower!)
 
*!  Stata version 9.0; stackmeWrapper v.4-8 updated Apr, Aug '23 & again Apr '24 to May'25' by Mark from major re-write in June'22

										// For a detailed introduction to the data-preparation objectives of the stackMe package, 
										// see 'help stackme'.

program define stackmeWrapper	  		// A 'wrapper' called by `cmd'.ado (the ado file named for any user-invoked stackMe cmd) 

scalar save0 = "`0'"					// Save existing macros of relevance to this invocation of 'stackmeWrapper' so that 
scalar dirpath = "$dirpath"				// we can drop all such macros using the first substantive command illustrated below.
scalar filename = "$filename"			// (then replacing needed macros from these scalar copies).
scalar pauseon = "$PAUSEON"
										// This wrapper calls `cmd'O, once each, for several commands and then repeatedly calls 
										// `cmd'P (the program doing the heavy lifting for that command) where context-specific 
										// processing generally takes place. It also parses the user-supplied stackMe command line, 
										// reduces the active data to user-named or user-implied variables and sets up options and 
										// varlist(s) for the calls on `cmd'O and `cmd'P. Finally this wrapper returns program
										// execution to the original calling program, which post-processes the outcome data as per
										// user-specified options.
*		********						
* 		Summary:						// Wrapper for stackMe version 2.0, June 2022, updated in '23, '24 & '25. Version 8 extracts 
*		********						// working data (variables and observations determined by each stackMe command-line) before  
										// making (generally multiple) calls on `cmd'P', once for each context and (generally) stack. 
										// These multiple calls avoid the need to evaluate an 'if' expression separately for each 
										// observation, greatly reducing processing time. Processing time is also economised by 
										// processing multiple varlists on a single pass through the data. 
										//
										// Processed data for each context-stack is progressively appended to a separate file from 
										// which it is merged back into the working data when all contexts have been processed. Care 
										// is taken to restore the original data before terminating execution after any anticipated
										// error. (Unanticipated errors are also captured and original data restored so that the user 
										// is not confronted with a working dataset consisting of only a single context and stack). 
										// Anticipated errors that are displayed as "program error" are not really anticipated and 
										// should be reported to the authors, along with a copy of the command-line responsible.
*		*******							//
* 		Syntax:							// General syntax: << cmd varlst [ifin] [wt] [ || varlst [wt] || ... || varlst [wt] ], optns >> 
*		*******							// Varlist syntax: << [str_] [prefixvars :] varlist [ifin][wt] >>
										//
										// With this general syntax, an initial string (a prefix for labeling outcome variables) can 
										// only occur before a prefixvar(list); 'ifin' must follow the first varlist; 'options' must 
										// follow the last varlist; 'weight's can follow any varlist. These variations reduce to a 
										// standard Stata command line: << cmd varlst [ifin] [wt], options' >>, as shown above. With 
										// this second (more traditional) syntax, prefixvars and their preliminary strings become 
										// additional options.
*		**********						//
* 		Structure:						// StackMe commands are not totally uniform in their structure or data requirements, so this 
*		**********						// wrapper program contains codeblocks that are specific to particular stackMe commnds. But the
										// general structure of the wrapper, as embedded in the entire stackMe package, is as follows...
										//
										// 0. Invoke appreviated caller (e.g. 'gendi', if invoked) to call the actual calling program 
										// (e,g, 'gendist', which can also be invoked directly). There construct an 'options mask' 
										// from which a syntax command will be derived in 'stackmeWrapper', the common ado file that
										// parses the command lines for all stackMe commands and governs the ensuing path taken in
										// order to fulfil each command, as follows...
										//
										// 1. Parse the syntax, separate varlists from options, parse the options, extract a list 
										// of vars needed by those options that must be included in context-specific working dta (this
										// takes a suprising amount of code). From each input varlist, extract the names that will 
										// govern the construction of outcome variable names. On the basis of these two lists, form 
										// a combined list uniquely identifying the variables needing to be retained in working dta.
										// Ensure that the names of variables to be created do not duplicate any existing names.
										//
										// 2. Save the original datafile for later merging with genereted variables; drop variables 
										// and oservations not needed in the working data; conduct preliminary checks for anticipated 
										// likely errors in the current 'cmd'P; often invoke a preliminary 'cmd'O (for 'open') – a
										// subprogram that performs preliminary processing that requires access to all observations  
										// in the dataset – before repeatedly invoking `cmd'P (for program), once for each context.
										//
										// 3. For each context (e.g. country-year-stack), preserve the working dataset and drop from 
										// the active data all contexts other than the currently active context (generally stack-within-
										// context but context-level for 'genstacks' and 'genplace'); invoke 'cmd'P (for program) that
										// does the heavy lifting, transforming input vars into appropriately-processed outcome vars.
										//
										// 4. Store the processed data for each context in a separate file. When all contexts have been
										// processed append each of those separate files to the first of them (the file on which the
										// full dataset is built); delete each of the tempfiles after appending. Finally merge the 
										// complete file of working data back into the original dataset (all new variables have new
										// names, generally constructed by prepending a prefix or adding a suffix to the original name).
										//
										// 5. Save working subset in a single tempfile that, after the first context (whose outcome
										// data is saved as a foundation), is appended to the growing tempfile of outcome data; restore 
										// the original dataset, mentioned in 2, above, and merge it with the tempfile of outcome data
										// from 3, above; report (if optioned) on missing observations per context and overall.
										// 
										// 6. Return execution to the original calling program where variables are renamed and otherwise
										// post-processed or dropped, as optioned, and Stata errors captured.
										//
										//			  Lines suspected of still proving problematic are flagged in right margin      	***
										//			  Lines needing customizing to specific `cmd's are flagged in right margin    	 	 **
*		************************		//						
*		commands to look out for		// Commands framed by asterisks play a critical role in defining stackMe package structure
*		************************		// (see examples to left). Comments framed in the same manner explicate features of stackMe 
										// package structure.
										//
*		*****************				//
		macro drop _all					// Global flags, etc., may have remained active on earlier error exit, so this cmd is issued
		local 0 = save0					//  here – the earliest point where all stackMe commands share the same lines of program code.
		global dirpath = dirpath		// Then immediately restore them from scalars saved on entry to 'stackmeWrapper', above.
		global filename = filename		//
		global PAUSEON = pauseon		//
		scalar drop save0 dirpath filename pauseon	
*		*****************				//
										//
*		*******************				//
global errloc "wrapper(0)"				// Used by subprogram 'errexit' and in the final codeblock of this wrapper program, where 
*		*******************				// unanticipated Stata-reported non-zero return codes are captured. Global 'errloc' stores a
										// string that labels each codeblock so as to facilitate identification of the likely location 
										// of any error. User errors are handled more specifically in the codeblocks where such errors 
										// are identified. All errors (ultimately) lead to a call on subprogram 'errexit' (below) which
										// restores the original data (if changed by the time the error is identified) before exit.
										
capture {								// Here is the opening capture brace that enclose the remaining wrapper code, except for a final
										// codeblock that processes any captured errors. (That codeblk follows the close brace that ends
										// the span of code within which errors are captured).
										
										
										
  
pause (0)								// (0)  Preliminary codeblock establishes name of latest data file used or saved by any 
										// 		Stata command and other globals needed throughout stackmeWrapper. Further 
										//		initialization for a large numbers of locals is documented at start of codeblk (2)
										

	local fullname = c(filename)							// Path+name of datafile most recently used or saved by any Stata cmd.
	local nameloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Position of first char following FINAL "/" or "\" of directory path
	if strpos("`fullname'", c(tmpdir)) == 0  {				// Unless c(tmpdir) is contained in dirpath (that leads to a tempfile)..
		global dirpath = substr("`fullname'",1,`nameloc'-1)	// `dirpath' ends w last `c(dirsep)' ("/" or "\"); i.e. 1 char before name
		global filename = substr("`fullname'",`nameloc',.)	// Update filename with latest name saved or used by Stata
	}														// (needed by genstacks caller as default name for newly-stackd dtafile)

	global multivarlst = ""									// Global will hold copy of local 'multivarlst' for use by caller progs
															// (holds list of varlists as typed by user, with ":", separatd by "||")
															// (to be replaced in next version by globals holding parsed elements)
															
	global keepvars = ""									// As above, but with dups & separatrs removd, & addtnl optiond varnames
	global prefixedvars = ""								// Global will hold the list of prefixed vars from subprogram 'isnewvar'.
	global SMreport = ""									// Signals to wrapper, if not empty, that error msg was already reported
	global exit = 0											// Signals to wrappr whether lower-level prog exited due to 'exit 1' error
															// $exit==1 requires restoration of origdta; $exit==0 or $exit==2 doesn't
															// ('exit 1' is a commnd unlike $exit=1, which is a flag for callng progrm)
	global nvarlst = 0										// N of varlists on command line is initialized to 0 (updated by `nvarlst')
															
	capture confirm variable SMstkid						// See if dataset is already stacked
	if _rc  local SMstkid = ""								// `SMstkid' holds varname "SMstkid" or indicates its absence if empty
															// (will be replaced by local 'stackid' after checking that not optioned)
	else  {													// Else there IS a variable named SMstkid
	  local SMskid = "SMstkid"								// Record name of stackid in local stackid (always 'SMstkid', if any)
	  gettoken prefix rest : (global) filename, parse("_") 	// And check for correct prefix to filename
	  capture confirm variable S2stkid						// See if dataset is already double-stacked
	  if _rc  {			
		local dblystkd = ""									// if not, empty the indicator
		if `prefix'!="STKD" {
		  errexit "Dataset with SMstkid variable but no S2stkid should have filename with STKD_ prefix"
		}
	  }
	  
	  else  {
	  	local dblystkd = "dblystkd" 						// Else note that data are douybly-stacked
		if `prefix'!="S2KD" {
		  errexit "Dataset with S2stkid variable should have filename with S2KD_ prefix"
		}	  
	  }														// – 'genstacks' is caller that brought us here – has no access to locals)
	} //endelse
	
	global dblystkd = "`dblystkd'"							// And make a global copy accessible to other programs (e.g. 'genstacks')
															// (local `dblydtkd' may be empty)

	local multivarlst = ""									// Local will hold (list of) varlist(s) (also provide it to $multivarlst)
	local noweight = "noweight"								// Default setting assumes no weight expression appended to any varlist
	
	local needopts = 1										// MOST COMMANDS NEED OPTIONS-LIST (exceptns are ON 3rd line of codeblk 0.1)
															// (MORE OF THEM NOW CONTEXTS & STACKS ARE NO LONGER DECLARED on `cmd' line)***
	
	
	
	
global errloc "wrapper(0.1)"
pause (0.1)	

										// (0.1) Codeblock to pre-process the command-line passed from `cmd', the calling program.
										//       It divides up that line into its basic components: `cmd' (the stackMe commend name);
										//	    `anything' (the combined varlist/namelist and ifinwt expression); the comma followed 
										//	     by `options' appended to that expression; the syntax `mask' appended to the above;  
										//	     and two afterthoughts that are placed between the options and the mask.
											
					
	gettoken cmd rest : 0									// Get the command name from head of local `0' (what the user typed)
															// (gettoken primes local `rest' for the next 'gettoken', below,
	global cmd = "`cmd'"									//  and provides a global for use by other programs)
	if "`cmd'"=="gendummies" | "`cmd'"=="genmeanstats" local needopts = 0 
															// ADD ANY OTHER EXCEPTIONS, AS DISCOVERED 									***
	gettoken cmdstr mask : rest, parse("\")					// Split rest' into the command string and the syntax mask
						
	gettoken preopt rest : cmdstr, parse(",")				// Locate start of option-string within 'cmdstr' (it follows a comma)
	if "`rest'"!=""  local rest = substr("`rest'",2,.) 		// Strip off "," that heads the mask ('if' should not be needed)
	
	if strpos("`rest'",",")>0 {								// Flag an error if there is another comma (POSSIBLY SUBJECT TO CHANGE)		***
		local err = "Only one options list is allowed with up to 15 varlists{txt}"
*               	 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		errexit "`err'"										// Above template counts available 80 colums for one-line results display
		exit 1												// 'errexit' w msg as arg displays msg in results and also in stopbox
	}														// (but w msg as option also needs 'display' option to augment stopbox)
															// Exit with return code 1 is same as pressing 'break' key
															// 
	gettoken options postopt : rest, parse("||")			// Options string ends either with a "||" or with the end of cmd-line
															// (if it ends with "||" don't strip pipes from start of 'postop')
	local multivarlst = "`preopt' `postopt'"				// Local that will hold (list of) varlist(s) (POSSIBLY SUBJECT TO CHANGE)	***
															// (it doesn't matter where `options' sat within `cmdstr'; this code
															//  leaves us with complete `multivarlst' and separate `options') 
															// (Note that pipes left at start of 'postopt' now terminate 'preopt')
	

	
global errloc "wrapper(0.2)"	
pause (0.2)
										// (0.2) Codeblock to extract the `prefixtype' argument and `multiCntxt' flag that preceed 
										//		 the parsing `mask' (see any calling `cmd' for details); discovers the option-name 
										//		 of the first argument – an argument that will hold any varname or list of varnames 
										//		 that might be supported by a stackMe command and might instead be supplied by a 
										//		 pre-colon prefixlist prepended to each varlist (varlist prefixes can be different 
										//		 for each varlist whereas options cannot).
												 
	
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
	}														//  of mask, but with "multicntxt" flag and leading "\" removed
	gettoken preparen postparen : mask, parse("(")			// Identify the option-name for critical 1st option by parsing on "("
	local opt1 = lower("`preparen'")						// Deal with any capitalized initial chars in this option name
															// (leaves the lower case version of 1st optn in 'opt1', needed below)
	local saveoptions = "`options' `prfxtyp'"				// Append 'prfxtyp' to 'options' so it can be parsed by syntax command
															// (along with user-supplied options)
	
	
	
																	
global errloc "wrapper(1)"																
pause (1)


										// (1) Process the options-list (found following the perhaps several varlists from codeblk 0.1)
										// 	   (some code supporting multiple options lists is retained in case of a future revision)

										
	local keep = ""										// will hold 'opt1' from 0.2 plus contextvars itemname stackid if optd
	
	local options = "`saveoptions'"						// Retrieve `options' saved in codeblk 0.1
	
	if substr("`options'",1,1)==","  {					// If `options' (still) starts with ", " ... APPARENTLY IT DOESNT				***
		local options = strltrim(substr("`opts'",2,.))	// Trim off leading ",  " 
	}						
														// This code permits successive optlists to update active options
														// (experimantal code now redundant but retained pending future evolution)
														
	if "`options'"!=""  {								// If this varlist has any options appended ...							
	 
		local opts = "`options'"						// Cannot use `options' local as that gets overwritten by syntax cmd)\
		
		gettoken opt rest : opts, parse("(")			// Extract optname preceeding 1st open paren, else whole of word
														// NOTE: 'opt' and 'opts' are different locals

/*														// duprefix WAS NOT IMPLEMENTED IN LATEST VERSION OF GENDUMMIES?				***				
		if "`cmd'"=="gendummies" &"`opt'"=="prefix" { 	// (any unrecognized options might be legacy option-names)
			display as error "'prefix' option is is named 'duprefix' in version 2. Exiting `cmd'." 
			window stopbox stop "Prefix option is named 'duprefix' in version 2. Exiting command."	
		}												// (also, `opt' is named `opt1', saved at end of codeblk 0.2)
*/		if "`cmd'"=="gendist"  {
		   if "`respondent'"!=""   {
		      errexit "Option 'respondent' is option 'selfplace' in version 2" // 'msg' arg is displayed and stopboxed
			  exit 1									// ('msg' as argument is stopboxed but needs 'display' option to be displayed)
		   }
		}
		
		

														// ('ifin' exprssns must be appended to first varlist, if more than one)
		local 0 = ",`opts' "  							// Named opts on following syntax cmd are common to all stackMe commands 		
														// (they supplement `mask' in `0' where syntax cmd expects to find them)
														// Initial `mask' (coded in the wrapper's calling `cmd' and pre-processed
														//  in codeblock 0 above) would apply to all option-lists `in multioptlst'
														//											 (dropped from current versn)
*		***************									// (NEW and MOD in this syntax command anticipate future development)			***
		syntax , [`mask' NODiag EXTradiag REPlace NOCONtexts NOSTAcks KEEpmissing APRefix prfxtyp(string) SPDtst * ] 
/*	    **************/	  							  	// `mask' was establishd in caller `cmd' and preprocessd in codeblk (0.2)
														// (Option SPDtst uses supposedly slower but simpler append file code)
														// (Final asterisk in 'syntax' places unmatched options in `options')
		if "`options'"!=""  {							// (So here we check for user option that does not match any listed above)
			display as error "Option(s) invalid for this cmd: `options'"
			errexit, msg("Option(s) invalid for this cmd: `options'")
			exit 1										// Alternative format for call on errexit, permits additional options (q.v.)
		}		


		local lastwrd = word("`opts'", wordcount("`opts'"))	// Extract last word of `opts', placed there in 0.2 & parsed above
		
		**************
		local optionsP = subinword("`opts'","`lastwrd'","",1) // Save 'opts' minus its last word (the added 'prfxtyp' option)
*		**************									// (put in 'optionsP' at end of codeblk 1.1 for use solely in wrapper)
*
														// Pre-process 'limititdiag' option
		if `limitdiag'== -1 local limitdiag = .			// Make that a very big number if user does not invoke this option
		if "`nodiag'"!=""  local limitdiag = 0			// One of the options added to `mask', above, 'cos presint for all cmds
		local xtra = 0
		if "`extradiag'"!=""  local xtra = 1			// Flag determines whether additional diagnostics will be provided
		
		if "`SMskid'"==""  {							// If there is no SMstkid, the data are not stacked
			if "`cmd'"=="genplace" {
				 errexit "Command genplace requires stacked data"
			} 	
		}
		
		if "`stackid'"!=""  errexit "In {bf:stackMe} version 2 the stack id is named SMstkid by command {bf:genstacks}"
*						 		     123456789012345678901234567890123456789012345678901234567890123456789abcdefghijk
		local stackid = "`SMstkid'"						// Local 'stackid' cannot be optioned in v2, so is used within wrapper
														// (as it was in version 1, for many flagging purposes)
		if ("`nostacks'" != "")  local stackid = "" 	// But treating stacked data as unstacked is still possible				***
														// (except in genstacks, where it is treated as an error – see 'cmd'O)
														
		if "`stackid'"!=""  {							// Else have SMstkid
		
			  capture confirm variable S2stkid			// So check if also have S2stkid
			  if _rc==0  {
				local dblystkd = "dblystkd"
				if `limitdiag' noisily display "NOTE: This dataset appears to be double-stacked (has S2stkid variable){txt}"
*						 		                1234567890123456789012345678901234567890123456789012345678901234567890123
			  }
			  else  {									// Stacked but not doubly-stacked
			    if `limitdiag' noisily display "NOTE: This dataset appears to be stacked (has SMstkid variable){txt}"				
			  }
			
		} //endif 'stackid'								// SMstkid and other such will be put in working data 
														// (after 'origdta' has been saved)
		
														// Identify optioned var(lists) to keep; 'genplace' has two of them
				
														
*		local actn = 0									// Set action flag to 0	(actions identified when flag is reset)
	    local opterr = ""								// local will hold name(s) of misnamed var(s) discovered below
	    local optadd = ""								// local will hold names of optioned contextvars to add to keepvars

		
		
		
	
global errloc "wrapper(1.1)"		
pause (1.1)


										// (1.1) Deal with 'contextvars' option/characteristic and others that add to the 
										//		 variables that need to be kept in the active data subset
										
										
		local usercontxts = "`contextvars'"			// To avoid being confused with contextvars from data characteristic

*		**********************							// Implementing a 'contextvars' option involves getting charactrstic
		local contexts :  char _dta[contextvars]		// Retrieve contextvars established by SMcontextvars or prior 'cmd'
*		**********************							// (not to be confused with 'contextvars' user option)

*noisily display "contexts `contexts'"

		local opterr = ""								// Empty this local which will carry an error message
		
		if `limitdiag'  {								// Much of what is done involves displaying diagnostics, if optioned
		  noisily display "{txt} "						// Insert a blank line if diagnostics are to be displayed
		
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
				  errexit "This file's contextvars charactrstic names variable(s) that don't exist: `contexts'"
				  exit 1
			} //endif

		    else  {										// Else data characteristic holds valid contextvars
				noisily display "Contextvars characteristic shows established contextvars: `contexts'{txt}" 			
*		         				 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			}
			
			 		  
			if "`usercontxts'"!=""  {					// If contextvars were user-optioned
			  local same : list contexts === usercontxts
			  if `same'  noisily display ///			// Returns 1 if two strings match (even if ordered differently)
				"NOTE: redundant 'contextvars' option duplicates established contexts{txt}"
*		         1234567890123456789012 3456789012345678901234567890123456789012345678901234567890
			  else  { 
				 noisily display ///
			     "Optioned contextvar(s) temporarily replace(s) established data characteristic" 
*		          1234567890123456789012 3456789012345678901234567890123456789012345678901234567890
				 local contexts = "`contextvars'"
			  }

			} //endif 'contextvars'
			
		  } //endif 'contexts'
		  
		  
		  else  {										// Else _dta[contextvars] characteristic was empty
		  
			local opterr =  /// 						//  Non-empty 'opterr' gets this msg displayed at end limitdiag
			     "stackMe utility {help stackme##SMcontextvars:SMcontextvars} hasn't initialized this dataset for stackMe"
*		                     12345678901234567890123456789012345678901234567890123456789012345678901234567890
			
		  } //endelse
		  
		} //endif 'limitdiag'							// Next check involves an actual error that terminates execution
	
		
		if "`opterr'"!=""  {
		   display as error "`opterr'"					// This is the 'not initialized for stackme' error message above
		   if "`usercontxts'"!=""  {					// If there are user-optioned contextvars
			  display as error "Instead establish optioned contextvars as this file's data characteristic?{txt}"
*		                        12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  capture window stopbox rusure ///
					"Instead establish optioned contextvars as this file's data characteristic?"
			  if _rc  {
			  	 display as error "Use stackMe utility {help stackme##SMcontextvars:SMcontextvars} to initialize this dataset{txt}"
*		                           12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  	 errexit "Use stackMe utility SMcontextvars to initialize this dataset"
			  }
			  else {									// Else user is OK with defining data characteristic & continue execution
			  	local opterr = ""
				char define _dta[contextvars] `usercontxts' 
				noisily display "Data characteristic now established as `usercontxts'"
			  }
			  local optionsP = subinstr("`optionsP'", "contextvars(`contextvars')","",1)	
														// Above code makes it as though 'contextvars' had not been optioned
		   }											// (so remove them from cmd-line options-list)
		   
		   else  {										// Else usercontxts were not optioned for this command
			  noisily display "Use stackMe utility {help stackme##SMcontextvars:SMcontextvars} to initialize this dataset{txt}"
*		                       12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  errexit , msg "Use stackMe utility SMcontextvars to initialize this dataset"
			  exit 1
		   }
		   
		   if "`opterr'"!="" {
		   	  errexit("`opterr'")
			  exit 1
		   }
		   
		   else if `limitdiag'  display "Execution continues..."
		   
		} //endif 'opterr'
		
		
		if "`opterr'"=="" local contextvars="`contexts' " // Change of name fits with usage elsewhere in stackMe
														  // (use characteristic for contexts only if 'opterr' is empty)
														  // (else we are overriding contexts characteristic by using optioned vars)
														  // (added space at end of local averts error when kept vars are cumulated)
														
	
global errloc "wrapper(1.2)"
pause (1.2)

										// (1.2) Deal with first option, which will hold an indicator variable name if `'prefixtype 
										//		 is "var", else a string (depending on 'cmd'); also with references to SMitem amd
										//		 `itemname'
														
		
		local optad1 = ""								// Will hold indicator or cweight options
		local optad2 = ""								// Additional local to hold the other of 'cweight's two varname options
	
		local opterr = ""								// Reset opterr 'cos already dealt with previous set of error varnames

	
														// In the general case 'opt1' has name if first option in 'optMask'
		if "`cmd'"=="genplace"  {						// But if this is as a 'genplace' command varlst could have 1 of 2 names
		   local opt1 = "indicator"
		   if "`wtprefixvars'"!=""  {					// If `wtprefixvars' was optioned...
		   	  local opt1 = "cweight"					// Have 'opt1' contain' the name of that var
		   }											// So, just as tho it had been first in the optMask
		}
		
		if "``opt1''"!="" & "`prfxtyp'"=="var"  {		// (was not derived from above syntax cmd but from end of codeblk 0.2)
		   local temp = "``opt1''"						// If 'cmd' is 'genplace', `opt1's will be `cweight's or 'indicator's
		   foreach var of local temp  {					// Local temp gets varname/varlist pointed to by "``opt1'"
			  capture confirm variable `var'			// See if all these vars exist
			  if _rc local opterr = "`opterr' `var'"	// Extend 'opterr' if not
			  else local optad1 = "`optad1' `var'"		// Extend 'optad1' otherwise
		   }					
	    }
		


	      if "`opterr'"!=""  {							 // Here issue generic error msg if codeblk found any naming errors
		     errexit "Invalid optioned varname(s): `opterr'"
			 exit 1
	      }
		  
		
		
		if "`itemname'"!=""  {							// User has optioned an SMitem-linked variable
		   capture confirm variable `itemname'
		   if _rc  {
		      errexit "Optioned {opt itemname} is not an existing variable"
			  exit 1
		   }											// If 'itemname' survives this check it will be added to 'keepoptvars'		   
		}
		
				
	    if "``opt1''"!="" & "`prfxtyp'"=="var" {		// If first option names a variable
		
		   local keepvars = "``opt1''"					// Double quotes get us to the varname actually optioned
		   foreach var of local keepvars  {				// opt1 might be a varlist
		     capture confirm variable `var'				// Here get list of unconfirmed varnames
		     if _rc  local opterr = "`opterr' `var'"	// (in 'opterr)
		     else local optadd = "`optadd' `var'"		// Else add var to list of those in 'opt1'
		   } //next 'var'
		   
		   if "`opterr'"!=""  {
			  errexit "Variable(s) in 'opt1' not found: `opterr'"
			  exit 1
		   }
		 
		} //endif 'opt1'
														  	  // MOVED TO JUST AFTER SYNTAX CMD IN (1)
	} //endif 'options'

	
															
	local keepoptvars = strtrim(stritrim("`contextvars'"+    /// Trim extra spaces from before, after and between names to be kept
		 "`optadd' `optad1' `optad2' `itemname'")) 			  // Put all these option-related variables into keepoptvars. SMsstkid,
															  //  contextvars & other stacking identifiers will be handld separtly
															  // (`itemname' can be referenced only by using this alias)
															  // (NOT SURE WHAT BENEFIT USER GETS FROM REFERRING TO IT INDIRECTLY)		***	
	
	
	
	
global errloc "wrapper(2)"	
pause (2)
										// (2)  Ignoring genstacks (dealt with in codeblk 6 below), this codeblock extracts each
										//		varlist in turn from the pipe-delimited multivarlst and, after sorting the variables
										//		into input and outcome lists, pre-processes if/in/weight expressns for each varlist,
										//		then re-assembles those varlsts, shorn of 'ifinwt' expressns, into a new multivarlst
										//		that can be bassed to whatever 'cmnd'P is currentlu being processed.
	
	
*	if "`cmd'" != "genstacks"  {								// 'genstacks' command-line will be processed in codeblockk (6)
																// (it only has a single stublist and no 'ifinwt' expressions)
	   local varlists = "`multivarlst'"							// Here we process multivarlsts for other commands
																// Put the 'multivarlst' (from end of codeblk 0.1) into 'varlists' 
	   local multivarlst = ""									// Then empty it to be refilled with varlists shorn of ifinwt,opts
																// ('multivarlst' is reconstructed towards end of this codeblk)
	   local lastvarlst = 0										// Will be reset =1 when final varlist is identified as such
	   local outcomes = ""										// These vars will become string-prefixed outcome variables
	   local inputs = ""										// Only for 'genyhats' does one of these morph into an outcome var
	   local strprfx = ""										// (for other 'cmd's 'inputs' will hold supplementary input vars)
	   local strprfxlst = ""									// List of prefix strings; check in (3) not mistook for vars
	   local keepwtv = ""										// Up to 2 hopefully identified weight vars to be kept in (2.2)	
	   local temp = ""											// This will hold a genyhats prfxvar (the tail of a double-prefix)
	   local errlst = ""										// List of supposed varnames found not to exist
	   local opterr = ""										// Used repeatedly to collect list of erronious options/varnames
	   local ifvar = ""											// Optionally filled later in this codeblk
	   local wtexplst = ""										// Optionally filled later in this codeblk
	   local noweight = "noweight"								// Flag indicates no weight expression as yet for any varlist
	   local nvarlst = 0										// Count of varlsts in the multivarlst (defaults to 0, flaggng an error)
																// (updates $nvarlst as it is itself updated – SUBJECT TO CHANGE)		***

	  
	   *******************************************************************************************************************************
	   *																															 *
	   *	   multivarlst -> varlists -> anything -> inputs&outcomes -> check ->  ->  ->  ->  ->  ->  ->  keepvarlsts -> keepvars	 *
	   *	   												    gotSMvars -^  cw..t&indicator&prefix ^   ifvar&keepwtv ^  				 *
	   *	  																optadd&optad1&optad2 ^	   contextvars ^				 *
	   *																															 *
	   *	[Schematic of route to identifying vars that need to be kept in working data]											 *
	   *																															 *
	   *******************************************************************************************************************************																	
	
	
*	    ***********************	  									// `varlists' was initialized above from 'multivarlsts'
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
		   syntax anything [if][in][fw iw aw pw/]
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
		   		  errexit "Only 'weight' expressions are allowed on varlists beyond the first; not if or in"
*               		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  }								
		   } //endelse
		   
		   
		   if "`weight'"!=""  {										// If a weight expression was appended to the current varlist

			  local wtexp = subinstr("[`weight'=`exp']"," ","$",.)	// The trailing "/" in the weight syntax eliminates redundnt blank
																	// Substitute $ for space throughout weight expression
																	// (has to be reversed for each varlist processed in 'cmd'P)
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
		   } //endif 'weight'										// Weight expressions elaborated below & at end of codeblk (6.2)
		

		   else  {													// Else there was no weight expression appended to this varlst

			 if "`noweight'"==""  {									// If there was a previous `wtexp' (so this is not first 'nvarlst')
			   while wordcount("`wtexplst'"<`nvarlst'  {			// While previous 'wtexp' expression was missing
				 local wtexplst = "`wtexplst' null"					//  pad the `wtexplst' with null strings for each missing word
			   }													// (insures 'wtexplst' remains empty when passed to 'cmd'P in (7))

			 } //endif `noweight'
			 
		   } //endelse	
		   
		   local llen : list sizeof wtexplst
	  
		   while `llen'>0  & `llen'<`nvarlst'  {					// Finish up this varlist's contribution to wtexplst
			 local wtexplst = "`wtexplst' null"						// Pad any terminal missing 'wtexplst's (must be after 'endwhile')
			 local llen : list sizeof wtexplst
		   }		  												// More on wts at end of (2.1); they are tested in codeblock (6.2)
*		   ***************************************		  
		   global wtexplst`nvarlst' = "`wtexplst'"					// BELONGS WITH $varlist`nvarlst', ETC., FILLED AT END CODEBLK(2.2)
*		   ***************************************					// (wts dealt with here 'cos there is one per varlist)







global errloc "wrapper(2.1)"
pause (2.1)
										// (2.1) Here check on validity of vars split into in 'inputs' and 'outcomes'

		   
		   gettoken precolon postcolon : anything, parse(":")		// Parse components of 'anything' based on position of ":", if any
		   if "`postcolon'"==""  {									// If 'postcolon' is empty then there is no colon
			  capture unab vars : `anything'						// Stata will report an error if var(s) do not exist
			  if _rc {												// Non-zero return code suggests 'anything' does not contain varnames
			  	if "`cmd'"=="genstacks" local vars = "`anything'"	// genstacks inputs can be stubs that function like vars for now
			    else  error _rc										// If there was a non-genstacks error it will be fielded by caller
			  }														// Else vars are valid
			  else local outcomes = "`outcomes' `vars'"				// If there is no colon then 'outcomes' is extended with new 'vars' 
		   }			 											// (genstacks inputs can be stubs, which cannot be unab'd)
		
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
					  local input = "`temp'"						// Input(s) for this varlist
		              local inputs = "`inputs' `temp'"				// So append what was 'temp' to 'inputs' list
			       }												// (these are inputs that are not outcomes)
				   else  {											// Else command is genyhats (only 'cmd' where 'precolon' is a depvar)
					 local outcome = "`temp'"						// Outcome(s) for this varlist
					 local outcomes = "`outcomes' `temp'"			// Append to outcomes from previous var(list)s
				   } //endelse										// (these are outcomes that are also inputs)
				
				   local strprfx = "`preul'"						// Store prefix for this varlist (coded differently for gendummies)
				   local strprfxlst = "`strprfxlst' `preul'"		// And accumulate in strprfxlst the strprfx, if any, for each varlist
																	// (since 'postul' is not empty there must be a 'preul')
				} //endif 'postul'
			  
		        else  {												// Else precolon var has no "_" to define a leading string-prefix
				
				   local prfxvar = "`precolon'"						// So 'precolon' is a prefixvar
				   local postc = substr("`postcolon'",2,.)			// Strip the first char (a colon) from head of 'postc'
*				   if "`cmd'"!="genyhats"  {						// Special treatment for 'genyhats' after next 'else' DELETED		***
					 local input = "`precolon'"						// Input(s) for this varlist
		   	         local inputs = "`inputs' `precolon'"			// In the general case append each 'precolon' to 'inputs' list
					 local outcome = "`postc'"						// Outcome(s) for this varlist
				     local outcomes = "`outcomes' `postc'"			// (and append postc to outcomes from previous var(list)s)
*			       }												// (the post-colon varlists all hold outcomes that are also inputs)
				   
/*			       else  {											// Else this is a 'genyhats' cmd COMMENTED OUT 'COS SAME AS ABOVE 	***
					 local input = "`precolon'"						// Input(s) for this varlist
				     local inputs = "`inputs' `postc'"				// (and the post-colon varlists list inputs that are not outcomes)
					 local outcome = "`postc'"						// Outcome(s) for this varlist
				     local outcomes = "`outcomes' `precolon'"		// For genyh any pre-colon var is the depvars (one per varlist)
		           }
*/				
			    } //endelse 'cmd'=='genyhats'
			  
		     } //endelse `cmd'=='gendummies'						// NOTE: 'precolon' is neither outcome nor input for gendummies

	      } //endelse 'postcolon'
		
				
	      local multivarlst = "`multivarlst' `anything' ||"			// Here multivarlst is reconstructed without any 'ifinwt' expressns
																	// (any such were removed by Stata's syntax command; instead weights
*		  **************************************					// per varlst were encoded in $wtexp`nvarlst, (2), tho' belong here)
		  global varlist`nvarlst' = "`outcomes'"					// Store in globals where can be found by 'cmd'P and elsewhere
		  global prfxvar`nvarlst' = "`inputs'"
		  global prfxstr`nvarlst' = "`strprfx'"						// Contains prefixed varname, for gendummies, else just a prefix
		  global nvarlst = `nvarlst'								// Stores number of current varlist; ultimately n of varlists
*		  **************************************					// PARALLEL GLOBAL wtexplst`nvarlst' WAS FILLED IN CODEBLOCK (2)
													
	      if `lastvarlst'  continue, break							// If this was identified as the final list of vars or stubs,						
																	// ('break' ensures next line to be executed follows "} next while")

																
																
*	    ****************					
	    } //next `while'											// End of code processing successive varlists within multivarlst
*	    ****************											// Local lists processed below cover all varlists in multivarlst	
	
	


		local llen : list sizeof wtexplst							// Finish up the wtexplst now all varlists have been processed
	
		while `llen'<`nvarlst'  {	
	  	   local wtexplst = "`wtexplst' null"						// Pad any terminal missing 'wtexplst's (must be after 'endwhile')
		   local llen : list sizeof wtexplst
		}
	
*	} //endif 'cmd'!="genstacks"									// 'genstacks' cmdline is further processed in codeblk (6)							
			




global errloc "wrapper(2.2)"			
pause (2.2)

										// (2.2) Have checkvars check the validity of input and outcome variables and then establish 
										//		 whether there are appropriate SM vars in this dataset (really this should be two
										//		 separate calls since the two operations are unrelated)


	
	local check = strtrim(stritrim("`inputs' `outcomes'"))			// Check for variable naming errors among inputs & outcomes
																	// (first extract all redundant spaces)
	checkvars "`check'"												// Calls 'unab' for each var and hyphenated varlist
	local check = r(checked)										// Vars remaining in 'check' are good to go
																
	checkSM "`check'"												// Establishes whether SM
	local gotSMvars = r(gotSMvars)									// 'gotSMvars' lists any SMvars in the active dataset
	
	local keepvarlsts = "`keepvarlsts' `optadd' `check' `gotSMvars'" 
	local keepvarlsts = strtrim(subinstr("`keepvarlsts'",".","",.))	// Eliminate any "." in 'keepvarlsts' (DK where orignatd)
																	// Check is added 'cos would have exited had check not succeeded
																	// ('check' includes both inputs and outcomes)


	
* 	


global errloc "wrapper(3)"	
pause (3)

		
										// (3) Check various options specific to certain commands for correct syntax; add `opt1'
										//	   (and 'opt2 for genplace – the first variable(s) in any optionlist) to 'keep' list 
										//	   if the option(s) name variable(s).
										
										
	if "`strprfxlst'"!=""  {									// If we found a strprfx for any command ..
	   foreach item of local `strprfx' {						// Check if `varlists' from (2) accidentally has any of them
          local keepvarlsts = subinstr("`keepvarlsts'", "`item'", "", .) // If so, remove them (should be redundant)
		}
	} //endif
		
																// genii & genpl can have multiple prefix vars (other cmds not)
	if wordcount("`inputs'")>1 & "`cmd'"!="geniimpute" & "`cmd'"!="genplace"  {
		errexit "`cmd' cannot have multiple 'prefix:' vars (only geniimpute & genplace)"
		exit 1
	} //endif wordcount
																// End of code interpreting prefix types

	local keepvarlsts = "`keepvarlsts' `ifvar' `keepwtv'"		// Must be appended after exiting 'while' loop `cos only done once 
																// (list of vars/stubs will provide names of vars generatd by 'cmd')																
	
	if "`cmd'"=="genplace" & "`indicator'"!=""  {				// `genplace' is the only cmd with additional var-naming optn 		***
																// (beyond the 'opt1' option handled above; so handle it here)
		  gettoken ifwrd rest : indicator						// See if "if" keyword is first word in 'indicator'
		  local errstr = ""										// Set error string initially blank
				
		  if "`ifwrd'"=="if"  {									// If "`indicator'" string starts with "if"
		    gettoken ifind rest : rest, parse(")")				// Rest of if-expresseion ends with close parenthesis
			if "`rest'"!="" {
				local ifind = "`rest'"							// Extract if-expressn & put in `ifind' ('ifexp' holds varlst if exp)
				tempvar indicator								// If indicator is created with 'ifind', make it a tempvar
				qui generate `indicator' = 0					// So generate a new var with 'indicator' name, 0 by default
				qui replace `indicator' = 1 `ifind'				// Replace values of that variable to accord with 'ifind' expression
		    }													// ('ifind' may include varname(s) but don't need to keep those)
		    else unab indicator : `indicator'					// Else 'indicator' contains a varlist; have unab check it
		  } //endif
																// ('indicator' local now names either orig or tempvar variable)				
	} //endif 'cmd'=='genplace									// (will be overridden by indicator varlist prefix, if any)
	
	
																// ***************************************************************
	tempvar origunit											// Variable inserted into every stackMe dataset; (enables merge of
	gen `origunit' = _n											//    newly created vars with original data in codeblk 9)
																// ***************************************************************
																
	
	local keepvars = strtrim(stritrim(	///						// Include just-created 'origunit' which we need for merging back
				"`keepvarlsts' `inputs' `outcomes' `keepoptvars' `keepprfx' `origunit'"))


		


global errloc "wrapper(4)"
pause (4)
		
										// (4) Save 'origdta'. This is the point beyond which any additional variables, apart from
										//	   outcome variables generated by stackMe commands, will not be included in the full 
										//	   dataset after exit from the command or after restoration of the data following an 
										//     error. Here initialize ID variables needed for stacking and to merge working data 
										//	   back into original data. Ensure all vars to be kept actually exist, check for any 
										//	   daccidental duplication of existing vars. Here we deal with all kept vars, from 
										//	   whatever varlist in the multivarlst set (except SMvars, added below if needed)
										   
																
															
*	************
	tempfile origdta
	quietly save `origdta'						    		// Will be merged with processed data after last call on `cmd'P
*	************											// This is temporary file will be erased on exit ('origdta' will be
															// restored before exit in event of controled error exit)


			
*	***************
	if "`ifexp'"!=""  keep if `ifvar'						// ******************************************************************
*	***************											// NOTE: Any exit before this point is a type-2 exit not needing data 
															// to be restored. There should only be type-1 exits after this point
															// (these DO require the full dataset to be restored)
															// (in subprogram errexit, $exit=0 is not distinguished from $exit=2)
															// ******************************************************************


	local temp = ""											// Name of file/frame with processed vars for first context
	local appendtemp = ""									// Names of files with processed vars for each subsequent contx
			
	local keep = "`keepvars'"
	
	local keep = strltrim(subinstr("`keep'", ":", " ", .))	// Remove any colons that might have been in 'saveAnything'
	local keepvars=stritrim(subinstr("`keep'","||"," ", .)) // Remove any pipes ditto AGAIN THESE ARE PROBABLY NOW REDUNDANT		***

			

			
			


global errloc "wrapper(5)"			
pause (5)


										// (5) Deal with possibility that prefixed outcome variables already exist, or will exist
										//	   when default prefixes are changed, per user option. This calls for two lists of
										//	   global variables: one with default prefix strings and one with prefix strings revised 
										//	   in light of user options. Actual renaming in light of user optns happns in the caller
										//	   program for each 'cmd' after processing by 'cmd'P; but users need to known before
										//	   'cmd'P is called whether there are name conflicts. Meanwhile we must deal with any 
										//	   existing names that may conflct with outcome names, perhaps only after renaming.
	

	if "`cmd'" != "genstacks"  {							// 'genstacks' command does not prefix its outcome variables
	
	  unab keepanything : `outcomes'						// List of outcome variables collected in codeblock (2)
	  
	  local check = ""										// Default-prefixed vars to be checked by subprog `isnewvar' below
	  global prefixedvars = ""								// List of prefixed vars with varnames same as existing prefixed vars
	  global exists = ""									// Ditto, for list of vars with revised prefixes if optioned
	  global newprfxdvars									// Ditto, for list of of not already existing outcome vars 
	  global badvars = ""									// Ditto, vars w capitalized prefix, maybe due to prev error exit
															// (isnewvar called from each prefix-related codeblock that follows)  
	} //endif 'cmd'=='genstacks
	
	
															
	if "`cmd'"=="gendist"  {								// Commands should not create a prefixed-var that already exists
	    foreach prfx in d m p x  {							// Default prfx names just one char, used (eg) in option 'dprefix'
		   local pfx = "d`prfx'_"							// Construct corresponding outcome prefix with extra "d" for "dist"
		   if "``prfx'prefix'"!="" {						// If 'prfx'prefix (eg 'dprefix') was optioned
			  if substr("``prfx'prefix'",-1,1)!="_"  {		// If user did not append an underscore character
				 local `prfx'prefix = "``prfx'prefix'_"		// (then append that char to referenced string – hence double ``'')
				 local pfx = "d``prfx'prefix'"				// (then substitute that prefix for the default prefix)
			  }
			} //endif
			foreach var of local keepanything  {			// Only vars to be used as stubs need be checked
			  local check = "`check' `pfx'`var'"
			} //next var									// (Only if optioned is there chance of a merge conflct, subroutine
	    } //next prfx										// 'isnewvar' checks whether the prefixed var exists in 'origdta')
	    isnewvar `check', prefix("null")					// Subprogram 'isnewvar' will add to $exists list if already exists
	} //endif 'cmd'	== 'gendist'							// (permission to drop vars in that list will be sought following
															//  'genyhats' codeblock, below)
															// ('null' option signals no additional prefix (eg for gendummies)
	
	if "`cmd'"=="gendummies" {								// Commands should not create a prefixed-var that already exists
															// (gendummies concern is quite different from other 'cmd's)
	    foreach s of local keepanything  {					// DUPREFIX NOT IMPLIMENTED IN THIS VERSION OF gendummies					***
															// (below is commentd-out suggestd code for implimentng 'duprefix')
	  	  local stub = "`s'"								// By default the stubname is the name of the categorical var
		  if "`stubname'"!=""  local stub = "`stubname'"	// Replace with optioned stubname, if any
/*		  local prfx = "du_"								// Gendummies has non-standard prefix-strng usage; this is default
		  if "`noduprefix'"!="" local prfx = ""				// If 'noduprefix' is optioned, prepend empty string
		  if "`duprefix'"!="" & substr("`duprfix'",-1,1)!="_"  { // SEE ABOVE CAPITALIZED COMMENT
		    local prfx = "`duprefix'_"						// If `duprefix' is optioned, prepend that to varname
		  }													// (having first appended the end-of-stub marker "_", if needed)
		  else local prfx = "`duprefix'"
*/															// 'gendummies' generates multiple vars for each stub
		  quietly levelsof `s', local(list)					// Put in 'list' the values that will suffix each new varstub
		  local llen : list sizeof list						// How long is this list?
		  
		  if `llen'>15  {									// If greater than 15 new vars				
			display as error ///							   
	      "Variable `stub' generates `llen' new vars; see {help gendummies##categoricalVars:SPECIAL NOTE ON CATEGORICAL VARS}{txt}"
*						      12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			capture window stopbox rusure ///
			     "Variable `stub' will generate `llen' new vars – see gendummies SPECIAL NOTE; continue anyway?"
			if _rc  {
				 errexit "No permission to continue"
			}
		    noisily display "Execution continues ..."

		  } //endif 'llen'									// If we emerge from this codeblk
		
		  if "`includemissing'"!=""  {						// If 'includemissing' was optioned, generate var w' 'mis' suffix
		    local check = "`check' `prfx'`stub'mis" )		// SEE IF THIS MATCHES WHAT I DO IN gendummies							***
		  }													// (and append to 'check' - only once nomatter how many there are)
		
		  foreach n of local list  {						// 'list' is the list of values (levels) that will suffix the stub
		    local check = "`check' `prfx'`stub'`n'"			// Generate varnamess by adding numeric suffix to stubnames
		  } //next var										// (inclusion of `prfx' just adds a leading blank if there is no 'prfx')
															// (insurance in case we decide to use a 'du_-prefix)
		  isnewvar `check', prefix(null)					// Subprogram 'isnewvar' will add to $exists list if already exists
		  local check = ""									// Empty this local preparatory to finding levels of next var, if any
															// (permission to drop vars in that list will be sought following
	    } //next 's'										//  'genyhats' codeblk, below)
															// 'null' option signals no pre-stub prefix (may come for gendummies)
	} //endif 'cmd'=='gendummies'

	
	
	if "`cmd'"=="geniimpute"  {								// Commands should not create a prefixed-var that already exists
	    foreach prfx in i m  {								// Default prfx names just one char, used (eg) in option 'dprefix'
		   local pfx = "i`prfx'_"							// Construct corresponding outcome prefix with extra "d" for "dist"
		   if "``prfx'prefix'"!="" {						// If 'prfx'prefix (eg 'dprefix') was optioned
			  if substr("``prfx'prefix'",-1,1)!="_"  {		// If user did not append an underscore character
				 local `prfx'prefix = "``prfx'prefix'_"		// (then append that char to referenced string – hence double ``'')
				 local pfx = "i``prfx'prefix'"				// (then substitute that prefix for the default prefix)
			  }
			} //endif
			foreach var of local keepanything  {			// Only vars to be used as stubs need be checked
			  local check = "`check' `pfx'`var'"
			} //next var									// (Only if optioned is there chance of a merge conflct, subroutine
	    } //next prfx										// 'isnewvar' checks whether the prefixed var exists in 'origdta')
	    isnewvar `check', prefix("null")					// Subprogram 'isnewvar' will add to $exists list if already exists
	} //endif 'cmd'	== 'geniimpute'							// (permission to drop vars in that list will be sought following															// 'null' option signals no separate list of default-prefixed vars
															//  genyhats codeblock, below)
	
	
	if "`cmd'"=="genmeanstats"  {
		foreach prfx in N mn sd mi ma sk ku su sw me mo  {
		   local pfx = "`prfx'"								// No cmd initial for genmeanstats (each stat already has 2 initials)
		   if "``prfx'prefix'"!="" {						// If 'prfx'prefix (eg 'dprefix') was optioned
			  if substr("``prfx'prefix'",-1,1)!="_"  {		// If user did not append an underscore character
				 local `prfx'prefix = "``prfx'prefix'_"		// (then append that char to referenced string – hence double ``'')
				 local pfx = "``prfx'prefix'"				// (then substitute that prefix for the default prefix)
			  }
		   } //endif
		   foreach var of local keepanything  {
			  local check = "`check' `pfx'`var'"
		   } //next var										// (Only if optioned is there chance of a merge conflct, subroutine
		} //next prfx										//  'isnewvar' checks whether the prefixed var exists in 'origdta')
															// (program isnewvar, below, asks for permission to replace if so)
		isnewvar `check', prefix("null")					// Subprogram 'isnewvar' will add to $exists list if already exists
															// (permission to drop vars in that list will be sought following
	} //endif `cmd'=='genmeanstats'							//  'genyhats' codeblock, below)
	
	
	
	if "`cmd'"=="genplace"  {								
	    foreach prfx in i m p  {							// Default prfx names just one char, used (eg) in option 'dprefix'
		   local pfx = "p`prfx'_"							// Construct corresponding outcome prefix with extra "p" for "place"
		   if "``prfx'prefix'"!="" {						// If 'prfx'prefix (eg 'dprefix') was optioned
			  if substr("``prfx'prefix'",-1,1)!="_"  {		// If user did not append an underscore character
				 local `prfx'prefix = "``prfx'prefix'_"		// (then append that char to referenced string – hence double ``'')
				 local pfx = "p``prfx'prefix'"				// (then substitute that prefix for the default prefix)
			  }
			} //endif
			foreach var of local keepanything  {			// Only vars to be used as stubs need be checked
			  local check = "`check' `pfx'`var'"
			} //next var									// (Only if optioned is there chance of a merge conflct, subroutine
	    } //next prfx										// 'isnewvar' checks whether the prefixed var exists in 'origdta')
	    isnewvar `check', prefix("null")					// Subprogram 'isnewvar' will add to $exists list if already exists
	} //endif 'cmd'=='genplace								// (permission to drop vars in that list will be sought following
															//  'genyhats' codeblock, below)
															// ('null' option signals no additional prefix (eg for gendummies)		

		
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
	} //endif `cmd'=='genyhats'								// (and drop the prefixed vars if user responds with 'ok')
		
		

															// Here issue any error message arising from the above checks
	if "$exists"!=""  {										// (this is list of errors found by subprogram 'isnewvar')
	   display as error _newline "These outcome variable(s) already exist: $exists{txt}" // Forty character overhead
*						          12345678901234567890123456789012345678901234567890123456789012345678901234567890 
	   display as error "Drop these?{txt}"
	   if strlen("$exists")>277  global exists = substr("$exists",1,277) + "..." // Stopbox only holds 320 chars
	   capture window stopbox rusure "Drop outcome variable(s) that already exist?:  $exists"
	   if _rc  {											// Non-zero return code tells us dropping is not ok with user
		 errexit "No permission to drop existing vars"		// Set $exit==2 `cos no need to restore data before exit
		 exit 1												// (not yet changed working data from what is in 'origdta')
	   }													// (NOTE: 'exit 1' is a command that exits to the next level up)
	   else  {												// Else drop these existing vars
	   	 drop $exists
	   }													// (when that is restored in codeblk (10) below)
	} //endif $exists  
	
	
	
	if "$badvars"!=""  {									// If there are vars w upper case prefix, maybe from prior error exit
	   display as error "Some vars seemingly left from earlier error exit: $badvars{txt}"
	   display as error "Drop these?{txt}"					// (produced by subprogram 'isnewvar', bi-product o code above)
	   if strlen("$exists")>277  global exists = substr("$exists",1,260) + "..." // Stopbox only holds 320 chars
	   capture window stopbox rusure "Drop variabless seemingly left from earlier error exit?: $badvars"
*						              12345678901234567890123456789012345678901234567890123456789012345678901234567890 
	   	 if _rc  {											// Non-zero return code tells us dropping is not ok with user
		 errexit, msg("No permission to drop unused vars") displ orig("`origdta'") // 'origdta' link ensures restore of those data
															// (might have changed working dta by dropping $exists)
	   }
	   else  {												// Else drop these existing vars
	   	 drop $badvars
*		 global badvars = ""								// This global retained to drop vars already saved in 'origdta'			***
	   }													// (NOT SURE WHY when that is restored in codeblk (10) below)
	} //endif $badvars
	
	
	
	if "$newprfxdvars"!=""  {								// This global was filled by subprogram 'isnewvar'  
															// (bi-product of code earlier in thes codeblk)
		local newprfxdvars = "$newprfxdvars"				// Could avoid this line if '(global) newprfxdvars' is allowed
		local dups : list dups newprfxdvars
		if "`dups'"!=""  {
			local ndups = wordcount("`dups'")
			local msg = "`ndups' duplicate outcome varname(s)"
			if "`stubname'"!="" & `nvarlst'>1 {				// If 'stubname' was optioned and there are >1 varlists
				local msg = "msg' (N.B. option stubname governs all varlists)" // ('stubname' can only be optioned in gendummies)
			}
			if `xtra' & `ndups'>1  {						// Detailed namelist only provided if 'xtra'diag & >1 name
				if substr("`msg'",-1,1)==")"  display as error "`msg'" // (version with parenthasized addition)
				else  display as error "`msg'": _continue	// For shorter msg display varnames starting on same line
				noisily display "`dups'"
				errexit, msg("`msg'; see full list displayed in results window") orig("`origdta'")
			}												// (no 'display' option 'cos already displayed on console)
			else  errexit, msg("`msg'") displ orig("`origdta'")	// Else display one of above msgs also on console
		}													// ('orig' option provides tempfile name to restore original dtaset)
			
	} //endif $newprfxdvars
		
			

	  

	
	
	
	
global errloc "wrapper(5.1)"
pause (5.1)


										// (5.1) Call on '_mkcross' to enumerate all contexts identified by a single variable
										//		 that increases monotonically in increments of a single unit across contexts
										//		 (the final variable we need to include in the working dtaset)
										//		 Also check whether data has Stata missing data codes (>=.)
			
*	**********	
*	if ! $exit  {											// If NOT already had an error requiring restoration of origdta
*	**********												// (THIS LINE OF CODE SHOULD BE OBSOLETE HAVING INTRODUCED 'errexit')	***
		
	  tempvar _ctx_temp										// Variable will hold constant 1 if there is only one context
	  tempvar _temp_ctx										// Variable that _mkcross will fill with values 1 to N of cntxts
	  capture label drop lname								// In case error in prev stackMe command left this trailing
	  local nocntxt = 1										// Flag indicates whether there are multiple contexts or not

	  if "`contextvars'" != "" | "`stackid'" != ""  local nocntxt = 0  // Not nocntxt if either source yields multi-contxts

	  if `nocntxt'  {
		gen `_temp_ctx' = 1									// Don't need _mkcross to tell us no contextvars = no contxts
	  } 
			
	  else {												// else we do have multiple contexts
			
		local ctxvars = "`contextvars' `stackid'"
															
		local optionsP = subinstr("`optionsP'", "contextvars(`contextvars')", "", .) // Remove 'contextvars' option if any
															// Substitute null str 'cos contextvars have morphed into 'ctxvars'
															// (this removes `contextvars' from `optionsP' – should not be there!)	***
*set trace off															
*		****************
		quietly _mkcross `ctxvars', generate(`_temp_ctx') missing strok labelname(lname)										 //	***
*		****************									// (generally calls for each stack within context - see above)
															// (enumerates only obs retained after 'ifexp' was executed in blk(4))
*set trace on

	  } // endelse 'nocntxt'
			
	  local ctxvar = `_temp_ctx'							// _mkcross produces sequential IDs for selected contexts
															// (NOT TO BE CONFUSED with `ctxvars' used as arg for _mkcross)
	  quietly sum `_temp_ctx'
	  local nc = r(max)										// This is the number of contexts (`c'), used below and in `cmd'P		
				
	
	
	
	
	  tempvar count											// Check whether Stata missing data codes are in use
	  local lastvar = word("`keepvars'",-1)					// Record this so can we tell when the last var has been tested
				
	  foreach var of local keepvars  {						// (similar code in 5.2 only if `showdiag'; & here overhead is small)
*set trace off
	    egen `count' = count(`var'>=.)  					// Count any observations with values >= missing
*set trace on
		if `count' in 1  continue, break					// Break out of loop with first Stata missing data code found
		
		if "`var'"=="`lastvar'"  {							// If this was the final variable in 'keepvars'..
			local msg = "No variable in the working dataset has any Stata missing data codes"
*					 	 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			display as error "`msg'; continue?{txt}"
			capture window stopbox rusure "`msg'; click 'cancel' and recode your missing data – or 'ok' to continue anyway"
			if _rc  {										// If user did not click 'OK'
				errexit, msg("Recode missing data") displ origdta("`origdta'") // Display msg in results window as well as stopbox
			}												// (we pass this point only if program did not exit)
		} //endif `var'
		
		noisily display "Execution continues..."
		
	  } //next var
		
*	} //endif !$exit										// IF-ENDIF BRACES NOW REDUNDANT 'COS WILL HAVE EXITED AFTER ERROR
	
	drop `count'											// Drop this tempvar

	
	
	
global errloc "wrapper(5.2)"		
pause (5.2)


										// (5.2) HERE ENSURE WEIGHT EXPRESSIONS GIVE VALID RESULTS in working dataset				***
							
										
				 
*	if  !$exit  {											  		  // Only execute codeblk if an error has not called for exit 
																	  // (NOW REDUNDANT SINCE errexit WILL HAVE EXITED ON ERROR)	***
	      forvalues nvl = 1/`nvarlst'  {							 
	   				 
		       if "`wtexplst"!=""  {								  // Now see if weight expression is not empty in this context

			     local wtexpw = word("`wtexplst'",`nvl')			  // Obtain local name from list to address Stata naming problem
				 if "`wtexpw'"=="null"  local wtexpw = ""
				 
				 if "`wtexpw'"!=""  {								  // If 'wtexp' is not empty (don't non-existant weight)
				   local wtexp = subinstr("`wtexpw'","$"," ",.)		  // Replace all "$" with " "
																	  // (put there so 'words' in the 'wtexp' wouldn't contain spaces)
				 
*				   ***************************							  
			       capture summarize `origunit' `wtexp', meanonly	  // Weight the only var known to exist in a call on `'summarize'
*				   ***************************						  // (known because we created it)

			       if _rc  {										  // A non-zero error code can only be due to the 'weight' expression

				     if _rc==2000  display as error "Stata reports 'no obs' error; perhaps weight var is missing in context `lbl' ?{txt}"
				     else  {
					   local l = _rc
					   errexit, msg("Stata reports program error `l' in context `lbl'") origdta("origdta")
					   exit 1										  // 'origdta' option ensures original dataset is restored before exit
				     }
error `l'
			         global exit = 1								  // Tells wrapper to exit after restoring origdata
				     continue, break								  // (must break out of loop before restoring)
																	  
			       } //endif _rc

		         } //endif `wtexpw'
				 
			   } //endif `wtexplst'
			 
		  } //next 'nvl'
		   
*	} //endif !$exit												  // IF-ENDIF BRACES NOW REDUNDANT 'COS WILL HAVE EXITED AFTER ERROR
		   
		   
/*																	  // COMMENTED OUT 'COS PREVIOUS ERRORS NOW ALL HANDLED BY 'errexit'		   
	if $exit  {											 	  		  // Any previous $exit==1 means restoring origdta then exit
*		***************
		capture restore										 		  // Not sure what can go wrong but evidently something did
		quietly use `origdta', clear
		exit 1
*		***************

*	} //endif !$exit
*/
	
					
global errloc "wrapper(6)"													
pause (6)
										// (6)   Issue call on `cmd'O (for 'cmd'Open). In this version of stackmeWrapper the
										//		 call occurs only for commands listed; 'genyhats' will have opening codeblocks 
										//		 transferred to this codeblk in a future release of stackMe. The programs 
										// 		 called here are final sources of vars to be kept.
															
	  	  	
															// Capture otherwise undiagnosed errors in programs called from wrapper
	
	  
	if "`cmd'"=="geniimpute" | "`cmd'"=="genmeanstats" | "`cmd'"=="genplace" |"`cmd'"=="genstacks" {  // cmds having a 'cmd'O
															// Above 'cmd's all have a 'cmd'O program that accesses full dataset
															// (may add gendist & genyhats so only gendummies will be w'out 'cmd'O)
		
*	 	******************** 
		`cmd'O `multivarlst', `optionsP' con(`USErcontxts') nc(`nc') nvar(`nvarlst') wtexp(`wtexplst') ctx(`_temp_ctx') orig(`origdta') 
*	 	********************								// (local c not included 'cos does not have a value at this point)
															// local 'origdta' IS included 'cos errors require origdta to be restored
	 
	 
		if "`cmd'" == "genstacks"  {						// Command genstacks deals with own varlist/stublist
			local keepimpliedvars = r(impliedvars)			// (and so overwrites 'keepimpliedvars')
			local multivarlst = r(reshapeStubs)				// Used in call on `cmd'P, thus feeding 'reshapeStubs' to `cmd'P
		} //endif 'cmd'=='genstacks'						// (instead of the sources that supply 'multivarlst' for other 'cmd's)
		
		if "`cmd'"=="genplace"  {
			local keeppl = r(keepvars)
			local multivarlst = "`multivarlst' `keeppl'"	// Add new var(s) from genplaceO to 'multivarlst'
		}

	} //endif 'cmd'== 										// End if clause determining whether 'cmd'O was called
															// ('cmd'O may itself have flagged an error)														
		
															
	local keep ="`keepvars' `keepimpliedvars' `keeppl'"   	// *******************************************************************
															// Last bit of 'keep' before dropping all other vars from working data
															// *******************************************************************													
	
	

	if $exit==1  {											// Some 'cmd'O commands may still use legacy error reporting
	
*	***************
	errexit, origdta("`origdta'")							// Use errexit to restore origdta and display "exiting" in stopbox
*	***************

	} //endif $exit
	

	
	
	local keep = subinstr("`keep'",".","",.)				// Drop any missing var indicators (DK where they come from)
	capture confirm variable SMstkid
	if _rc==0  local keep = "`keep' SMstkid"				// (and add 'SMstkid' for diagnostic displays)

	
*	*****************										// Check that all vars to be kept are actual vars
	capture unab keep : `keep'								// (May include SMitem or S2item generated just above)
*	*****************										
	

	
	
	global keepvars : list uniq keep						// Stata-provided macro function to delete duplicate vars
															// (put in global so can be accessed by 'cmd' caller and subprograms)
															// (`keepimpliedvars' is a list of varnames BEFORE stacking)
															// ($keepvars' is all varlists and optioned vars with dups removed)
																																					
*	**************											// HERE DROP UNWANTED VARIABLES FROM WORKING DATA FOR ALL CONTEXTS
	keep $keepvars `_temp_ctx' 								// Keep only vars involved in generating desired results
*	**************											// ($keepvars is `keep' with dups removed after 'unab', codeblk 6)
					


					
					
global errloc "wrapper(6.1)"				
pause (6.1)	
										// (6.1) Cycle thru each context in turn 'keep'ing, first, the variables discovered above to be
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
	forvalues c = 1/`nc'  {								 			  // Cycle thru successive contexts (`c')
*	********************


		local lbl : label lname `c'						 	// Get label associated by _mkcross with context `c' ('cmd'P 
															// programs can optionally have labelname 'lname' hardwired)

															
*		********										 	**************************************************************
		preserve  								 		 	// Next 3 codeblks use only working subset of context `c' data
*		********										 	**************************************************************


		

					

					
					
global errloc "wrapper(6.2)"					
pause (6.2)								// (6.2) THIS IS WHERE UNWANTED OBS ARE DROPPED FROM WORKING DATA, CONTEXT BY CONTEXT
										//		 This codeblock then creates a 'noobsvarlst' of vars with no obs in this context




*		************
		quietly keep if `c'==`_temp_ctx' 							// `tempexp' starts either with 'if' or with 'ifexp &'
*		************									 			// ('ifexp' now executed after saving 'origdta' in blk 4)
				
   
*		******************************************		   		  
		if `limitdiag'>=`c' & "$cmd"!="geniimpute" {		  		// Limit diagnostics to `limitdiag'>=`c' and !'geniimpute'																						 
*		******************************************				  
		

			showdiag1 `limitdiag' `c' `nc'

			  
		} //endif `limitdiag'>=`c' & ...
			 				 
							 
							 





global errloc "wrapper(7)"		
pause (7)
										// (7)  Issue call on `cmd'P with appropriate arguments; catch any `cmd'P errors; display 
										//		optioned context-specific diagnostics
										//		NOTE WE ARE STILL USING THE WORKING DATA FOR EACH IN TURN OF SPECIFIC CONTEXT `c'
										//		(IF NOT STILL SUBJECT TO AN EARLIER IF !$exit CONDITION)
										
																		
set tracedepth 5																		
*		*******************				     	 					  // Most `cmd'P programs must be aware of lname for ctxvars	***
		`cmd'P `multivarlst', `optionsP' nc(`nc') c(`c') nvarlst(`nvarlst') wtexplst(`wtexplst')
*		*******************											  // `nvarlst' counts the numbr of varlsts transmittd to cmdP


			  
		if $exit==1  {												  // Some 'cmd'P commands may still use legacy error reporting
	
*			***************
			errexit, origdta("`origdta'")							  // Use errexit to restore origdta and displ "exiting" in stopbx
*			***************

		} //endif $exit

			
			
		if `limitdiag'>=`c' & "$cmd"!="geniimpute" {				  // Limit diagnstcs to `limitdiag'>=`c' and !'geniimpute'		
		
	
*			showdiag2 `limitdiag' `c' `nc' `xtra'					  // MSGS FROM FOLLOWING CODE DON'T DISPLAY FROM SUBPROGRAM		***
			
			
			
			if `nc'>1  local multiCntxt = 1							  // Different text for each context than whole dataset
			else local multiCntxt = 0
	
			local numobs = _N										  // Here collect diagnostics for each context 
				   					  
			if `limitdiag'>=`c' & "$cmd'="!="geniimpute" {			  // `c' is updated for each different stack & context
								   
				local lbl : label lname `c'							  // Get label for this combination of contexts
					  
				local lbl = "Context `lbl'"							  // Below we expand what will be displayed
					  
				if ! `multiCntxt' {
					local lbl = "This dataset"
					if "cmd'"=="genstacks"  local lbl = "This dataset now" 
				}													  // Only for 'genstacks' referring to stacked data
					  
				local newline = "_newline"
				if "$cmd"=="genstacks" local newline = ""
*				noisily display "   `lbl' has `numobs' observations{txt}" _newline
					  
				capture confirm variable SMstkid					 // See if data are stacked
				if _rc==0  local stkd = 1
				else local stkd = 0
				
				local displ = 0
				if `stkd' {
					if SMstkid == 1  {							 	 // By default, if stkd, give diagnsts only for 1st stack
					   if `multiCntxt' & "$cmd"!="geniimpute" {		 // Geniimpute has its own diagnostics   
					   	  local displ = 1
						}
					}
				}
				
				else {												 // Else dataset is not stacked
					if `multiCntxt' & "$cmd"!="geniimpute" {		 // Geniimpute has its own diagnostics  			
						local displ = 1
					}
				}
				
				if `displ'  {
				   local msg = "   `lbl' has `numobs' observations"
*				   showmsg  "`msg'" 								 // Noisily display the msg – DOESN'T DISPLAY (see next) 
				   noisily display "`msg'"							 // DOES NOT DISPLAY IF THIS CODE IS RUN FROM SUBPROGRAM	***

				   if `xtra'  {									 	 // If 'extradiag' was optiond, also for other stacks
					  local other = "Relevant vars "				 // Resulting re-labeling occurs with next display
					  if "$noobsvarlst"!=""  {
						local errtxt = ""
						local nwrds = wordcount("$noobsvarlst")
						local word1 = word("$noobsvarlst", 1)
						local wordl = word("$noobsvarlst", -1)		 // Last word is numbered -1 ('worl' ends w lower L)
						if `nwrds'>2  {
							local word2 = word("$noobsvarlst", 2)
							local errtxt = "`word2'...`wordl'"
							if `nwrds'==2 local errtxt = "`wordl'"
							if `xtra' noisily display "NOTE: No observations for var(s) `word1' `errtxt' in `lbl'"
							local other = "Other vars "				 // Ditto
						}
					  }
					  
					  local minN = minN							 	 // Make local copy of scalar minN (set in showdiag1)
					  local maxN = maxN								 // Ditto for maxN
					  local lbl : label lname `c'
					  local newline = "_newline"
					  if "$cmd"=="genstacks" local newline = ""
					  
					  if `multiCntxt'  noisily display 				/// geniimpute displays its own diags
						 "`other'in context `lbl' have between `minN' and `maxN' valid obs"
						 
*					  noisily display "{txt}" _continue

				   } //endif 'xtra'
				
				} //endif 'displ'
						 
			} //endif 'limitdiag'

			else  {													// If limitdiag IS in effect, print busy-dots
		  
			  if `limitdiag'<`c' & `cmd'!="geniimpute"  {			// Only if `c'>= number of contexts set by 'limitdiag'
																	// (except for 'geniimpute' which does its own diagnostics)
					local busydots = "busydots"						// Flag forces final display. ending line of busydots
					
					if "`multiCntxt'"!= ""  {						// If there ARE multiple contexts (ie not gendummies)
						if `nc'<38  noisily display ".." _continue	// (more if # of contexts is less)
						else  noisily display "." _continue			// Halve the N of busy-dots if would more than fill a line
					}
					
			  } //endif
				
			} //endelse

			if `c'==`nc'  capture scalar drop minN maxN				// If this is the final context, drop scalars
			

*			end showdiag2											// MSGS FROM ABOVE CODE DON'T DISPLAY WHEN MOVED TO SUBPROGRAM	***

			
		} //endif `limitdiag'>=`c' & ..
			

			
			
		local skipsave = 0										    // Will permit normal processing by remainder of wrapper 
																    // (unless overridden by next line of code)			
		
		if "`cmd'"=="genplace" & "`call'"=="" local skipsave =1     // Skip saving outcomes if 'genplace' unless 'call' is optd
		

		if  !`skipsave'  {										    // If 'skipsave' was not turned on above..
		





		
global errloc "wrapper(8)"										    // This codeblock is only executed if 'skipsave' is not true
pause (8)


				
								// (8)	Here we save each context in a tempfile for merging once all contexts have been processed.
								//		This means recording a filename for each context*stack in a list of filenames whose length
								//	is limited by the maximum length of a Stata macro (on my machine 645,200 bytes.) So the first
								//	time a dataset is processed we need to check on the max for that machine, find the length of
								//	the tempname (the string following the final / or \) and see if the product of contexts*stacks
								//	is less. If not we must start another list that will ultimately be appended to previous lists.
								//  All of this is mind-bogglingly complicated so first we try a simpler strategy to speed-test it
								//  NOTE THAT WE ARE STILL USING THE WORKING DATA FOR A SPECIFIC CONTEXT `c'
			
*set trace on	

		  if "`spdtst'"!="" {										// If not empty, option 'spdtst' invokes simpler but slower code


			if `c'==1  {
							  					
			  tempfile wrapc1										// Declare tempfile to hold first context (will hold all contxts)
			  save `wrapc1'											// This file holds 1st contxt, basis for appending later cntxts
			  local fullname = c(filename)							// Path+name of that datafile (the last one used by any Stata cmd)
			  global wrapbld = "`fullname'"							// For some reason I forget we had to store this in a global
																	// (maybe 'cos, when we append, we are in different context?)
			}														// NOTE: $wrapbld was 'wrapc1' (will eventually hold all contxts)
			
			else {													// Else this is a context that needs to be appended to $wrapbld
			
			  tempfile wrapnxt										// Declare tempfile for current context (c2...cmax)
			  save `wrapnxt', replace								// Save this context in that file (so can append it to $wrapbld)
			  local fullname = c(filename)							// Path+name of latest datafile used or saved by any Stata cmd
			  global wrapnxt = "`fullname'"							// global holding name of tempfile holding current context
			  
			  use $wrapbld		
																	// Append data for current context to data from all past contexts
			  quietly append using $wrapnxt, nonotes nolabel		// SEEMINGLY NEED TO USE fullname, PRAPS 'COS ARE IN DIFFRNT CNTXT
			  save $wrapbld, replace								// Replace $wrapbld by itself with current context appended
			  erase $wrapnxt	
																	// Erase this tempfile after each useage
			} //endelse


									// 			*************************************************************************************
									// 			CODEBLOCK THAT MINIMIZES N OF TIMES EACH FILE IS SAVED/USED ...
									// 			(REPLACES ABOVE CODE STARTING WITH "if "`spdtst'" AND ENDING BEFORE "} //endif BELOW.
									// 			(see if can simplify this code by reducing it to two subprogram calls)					***
									// 			*************************************************************************************
		  } //endif 'spdtst'
		
		
		
		  else  {													// 'speedtest' was NOT optiond so use faster (if more verbose) code
		
			tempfile i_`c'											// We need one of these files for each context/stack
			quietly save `i_`c''									// Here create tempfile for each context, named "i_`c'"	
			local fullname = c(filename)							// Path+name of latest datafile used or saved by any Stata cmd
																	// (used to find total length needed for all prev files + this one)
			if `c'==1  {
																	// If this is 1st contxt, record base filename onto which to build
				global wrapbld = "`fullname'"						// Need to use same name for global as used in 'spdtst' code, above
				global wraptemp = "`i_`c''"							// ('cos 'c'==1 this is first element of $wrapbld, on which we build)
				local namloc =strrpos("`fullname'","`c(dirsep)'")+1	// Posn of first char following final "/" or "\" of directory path
				global savepath = substr("`fullname'",1,`namloc'-1)	// Path to final dirsep should be same for all successive files
																	// (path ends with dirsep – "/" or "\")
				local listlen2 = 0									// N of names in first list of files to be appended (none as yet)
																	// (numbered 2 for poor reason: it starts with the second context)
				local appendlst2 = ""								// Local holds 1st list of tempfile names (each starting with blank)
				local nlst = 2										// Number of current list used to store tempfile names
																	// (numbered 2 for same poor reason as above two locals)
*				local nname = 0										// Position of 'thisname' in currnt list of filenames (SEEMS UNUSED)***
				local nnames2 = 0									// Local nnames`nlst' is used to record n of names in appendlst#
			
			} //endif `c'==1
						
			
			else {													// Else `c' indicates context beyond the first (i.e. 'c'>1)
				
			   local thisname = substr("`fullname'",`namloc', .)	// Trailing name of file to hold data generatd for this context
			   local namlen = strlen("`thisname'")					// Get length of string holding 'thisname'
			   if `listlen`nlst''+`namlen' > c(macrolen) {			// If length of resulting list of names would be > c(macrolen)
*			      local nnames`nlst' = `nname'						// Store n of names in this full list (SEEMINGLY REDUNDNT, see below)
*				  local nname = 0									// Position of first name in the new list of filenames (DITTO)		***
				  local nlst = `nlst' + 1							// Increment n of lists holding these names; resets `name#')
				  local nnames`nlst' = 0							// For each filename-list this holds the N of names in that list
				  local listlen`nlst' = 0							// Zero the accumulated length in chars of next namelist
				  local appendlst`nlst' = ""						// Empty the next list of tempfile namesq

			   }
			   
			   local listlen`nlst' = `listlen`nlst'' + `namlen' + 1	// Add up space used for this list of filenames (prhps many dblstkd)
																	// (same 'namlen' as was used above to check if space was enough)
			   local appendlst`nlst'="`appendlst`nlst'' `thisname'" // Append it to current list (after the space counted as +1 above)
			   local nnames`nlst' = `nnames`nlst'' + 1				// Store the position (word#) of the current name within this list
																	// (becomes a count of the n of filenames in this list)
		    } //endelse	`c'==1										// End of codeblk dealing with contexts beyond the first
																	
		  } //endelse 'spdtst'										// END OF CODEBLOCK THAT MINIMIZES N OF TIMES FILES ARE OUTPUT/USED
																	// (code above is executed only if we are NOT using 'spdtst' code)

						
	    } //endif !'skipsave'										// Just to make things even more complicated, either code version is
																	// only executed if command is not 'genplace' (unless w 'call' optn)
		
		
*		*******
		restore														// Here finish with working contxt, briefly restore full workng data
*		*******														// (briefly unless this is the final context)
			
		if $exit continue, break									// Should not occur: any errors should have led to earlier exit
 
	   
*	  ********************
	} //next context (`c')											// Repeat while there are any more contexts to be processed
*	  ********************
		
	
	if "`spdtst'"==""  {											// If we are NOT testing speed of simpler code ...
	





																	// **************************************************************
global errloc "wrapper(8.1)"										// INCLUDE (8.1) IF MINIMIZNG N OF TIMES EACH CNTXT IS SAVED/USED	***	
pause (8.1)															// ****************************************************************

	
										// (8.1) After processng last contxt (codeblk 7-8), post-process outcome data for mergng w orignl
										//	     (saved) data. NOTE THAT THE DATA BEING PROCESSED IS NO LONGER THE WORKING DATA SUBSET
										
										
	  if !`skipsave'  {												// Skip this codeblock if conditions for executing it are not met
																	// (skipped only for genplace cmd with no 'call' option)
*	  quietly use $wraptemp, clear									// Open the file onto which, if multicntxt, more will be appended
																	// COMMENT OUT 'COS ALREADY OPEN
																	
		if "`multiCntxt'"!= ""  {									// If there ARE multi-contexts (local is not empty) ...
																	// Collect up & append files saved for each contxt in codeblk (8)
																	// (If there was only one context then just one was saved)
		   preserve													// Need to preserve again so as to append contexts to $wraptemp file

			  local nlst = 2										// Start with the first list out of the possible set of lists
			  local nname = 1										// Number (position) of this name in this list
		   
			  forvalues i = 2/`nc'  {								// Cycle thru all contexts whose filenames need to be appended

*				local temp = nnames`nlst'							// Trying to avoids error reading `nnames`nlst''
				if `nname'>`nnames`nlst''  {						// If 'nname' is beyond nnames saved for this list in codeblk (8)
					local nlst = `nlst' + 1							// (so increment n of lists holding these names; reset `name#')
					local nname = 1									// The next tempfile will hold the first remaining context name
				}
	
*				local temp = "appendlst`nlst'"
				local a = word("`appendlst`nlst''",`nname')			// Get name of this file in `appendlst`nlst''; append context
				quietly append using $savepath`a', nonotes nolabel	//  data to $wraptemp file using directory path to that contxt name
				erase $savepath`a'									// Erase that tempfile	($savepath ends with `dirsep')
				
				local nname = `nname' + 1							// Increment the position of next filename in this list
				 
			  } //next 'i'
																			
			  quietly save $wraptemp, replace						// File $wraptemp now contains all new variables from `cmd'P
																	// (for all contexts, each context separately appended above)
		   restore													// Restore the working dataset for the final context
		
	
		} //endif `multiCntxt'										// If not a multicontext dataset the one file is all there is
	  
	  } //endif !'skipsave'											// (skipped only for genplace commands with no 'call' option)
	  
    } //endif 'spdtst'												// END OF CODEBLOCK THAT MINIMIZES N OF TIMES FILES ARE OUTPUT/USED
	
	
	
	
global errloc "wrapper(9)"	
pause (9)

	
										// (9)  Recover `origdta', then the previous names of variables temporarily renamed to avoid 
										//		naming conflicts; merge new vars, created in `cmd'P, with original data

	if !`skipsave'  {										// Skip next codeblk if 'cmd' is 'genplace' without 'call' option

*	  ****************************										
	  quietly use `origdta', clear							// Retrieve original data to merge with new vars in $wraptemp 
*	  ****************************							// (vars built in 'cmd'P from vars in 'multivarlst)
															// If we skipped the saves, above, then we don't make any changes
															// (everything from codeblk 8 onward was just cosmetic in that case)

															// THIS NEXT BLOCK MAY BE REDUNDENT AFTER ADDING CODE ABOVE				***
	  if "$prefixedvars"!=""	{							// If there were any name conflicts for merging
															// (diagnosed before call on 'cmd'P)
	   foreach var of global prefixedvars  {				// This global was filled as a bi-product of codeblock (5) 
		  local prfx = strupper(substr("`var'",1,2))		// Change prefix string to upper case (it is followd by "_")
		  local tempvar = "`prfx'" + substr("`var'",3,.)	// All prefixes are 2 chars long and all were previously lower case
		  capture confirm variable `tempvar' 				// If it already exists we had the same conflict earlier
		  if _rc==0  drop `tempvar'							// (the prefix is capitalized so var can be dropped w'out harm)
		  else rename `var' `tempvar'						// Each 'var' has a "_" in 3rd character position
		} //next prefixedvar

	  } //endif $prefixedvars								// (skipped only for genplace commands with no 'call' option)

*pause merge	  
	  
*	  *****************	  
	  quietly merge 1:m `origunit' using $wrapbld, nogen update replace
*	  *****************										// Here merge the full working dta file w all cntxts back into `origdta'
															// (bringing with it the prefixed outcome vars built from 'multivarlst'
	  erase $wrapbld
	  
	  erase `origdta'
	  
	} //endif !'skipsave'
	
	if "`busydots'"!="" noisily display " "					// Override 'continue' following final busy dot(s)


	
	
	local skipcapture = "skipcapture"						// In case there is a trailing non-zero return code
	
	
} //end capture	







global errloc "wrapper(10)"
pause (10)
pause (10)



															
if _rc  & "`skipcapture'"=="" & "$SMreport"=="" {			// If unreported non-zero return code (should be captured Stata error)
															// (meaning that nature of error will not already have been displayed)
	local rc = _rc

	if "$exit"=="" global exit = 0							// If legacy $exit is empty that must be because it has not yet been set
		
	if $exit==1  {											// If $exit ==1 likely unexpected user error;  need to restore `origdta' 
															// This would have been in some 'cmd'P using legacy error reporting
		capture restore										// With $exit==1, data in memory have been changed
		use `origdta', clear								// (so restore copy of dataset that was in memory before began processing
		errexit "Likely user error in $errloc; click on blue error code for details" _rc
		exit _rc
	}														// (_rc is not dropped along with macros)
	
															// Else $exit was not set ==1	
	else  {
		errexit, msg("Likely program error in $errloc; click on blue error code for details") displ orig("`origdta'")
	}														// (option 'display' sends msg to console; `origdta' restores orig dta)
															// (any call on errexit sends msg to stopbox)
	
} //endif _rc & ! `skipcapture' & ! $SMreport


if "$SMreport"==""	{							// Drop all globals, restoring those needed by succeeding stackMe commands
												// (not if this was just done in errexit, if that was invoked)
	scalar filename = "$filename"				// Save, in a scalar, global filename – relevant for later stackMe cmds
	scalar dirpath = "$dirpath"					// Ditto for $dirpath
	scalar exit = "$exit"						// Ditto for $exit
	scalar multivarlst = "$multivarlst"			// Ditto for $multivarlst
	macro drop _all								// Clear all macros before exit (evidently including the above four)
	global filename = filename				    // But filename may be useful for later 'stackme' commands
	global dirpath = dirpath					// Ditto for dirpath
	global exit = exit							// Ditto for $exit
	global multivarlst = multivarlst			// Ditto fir $ultivarlst (used in most caller programs)
	scalar drop filename dirpath exit multivarlst // But we should overtly drop the scalars used to secure those loc/globals

}

	
end //stackmeWrapper							// Here return to `cmd' caller for data post-processing


************************************************* end stackmeWrapper ********************************************************




**************************************************** SUBPROGRAMS *************************************************************
*
* Table of contents
*
* Subprogram			Called from						Task
*
* checkSM				stackmeWrapper (2.2)			Establish list of SMvars (or special names) referenced by user
* checkvars				stackmeWrapper (2.2)			Alternative for unab that calls unab repeatedly, once for each var
* errexit				Everywhere						Optnly display error msg in Results windw; call stopbox stop w same msg
* getwtvars				stackmeWrapper (2)				Establish weight string for each nvarlst in a multivarlist
* isnewvar				stackmeWrapper (5)				Multiple times to see if vars w specific prefixes already exist
* showdiag1				stackmeWrapper (6)				Store diagnostic stats before calling 'cmd'P
* showdiag2				stackmeWrapper (7)				Display diagnostic stats after return from 'cmd'P
* showmsg				showdiag2						Display text with line breaks (currently unused)
* stubsImpliedByVars	genstacksO (twice)				Name says it
* varsImpliedByStubs	genstacksO						Name says it
* subinoptarg			unsure if called at all			Replace argument within option string
*
******************************************************************************************************************************





capture program drop checkSM

program define checkSM								// See of SMitem or S2item are among input/outcome vars


	args check													  // Argument 'check' contains list of non-'unab'ed variables	

										
		capture unab check : `check'
		
		local gotSMvars = ""									  // List of extant SM/S2 items
		local SMvars = ""										  // List of SMitem or S2item included  in 'check'
		local SMerrs = ""										  // SM/S2 items with no link to existing var ditto
		local SMbadlnk = ""										  // SM/S2 items whose link does not exist ditto
		local errlst = ""										  // List of broken links (linked vars that don't exist)
		
		if strpos("`check'", "SMitem")>0  local SMvars = "SMitem" // Check the same vars as checked above (inputs + outcomes)
		if strpos("`check'", "S2item")>0  local SMvars = "`SMvars' S2item" // (to see if user included SMitem or S2item)
	  
		foreach var of local SMvars  {							  // Cycle thru the (up to) 2 vars in 'SMvars'
	  	
		   local `var' = "`_dta[`var']'" 	  					  // Retrieve associated linkage variable from characteristc
		   
		} //next 'var'
		   
		if "`SMitem'" ==""  local SMerrs = "`SMerrs' `var'"		  // If SMitem isnt linked, extend list of unlinked SMvars
		else  local gotSMvars = "`gotSMvars' `var'"		  		  // Else extend list of linked SMvars
		   
		if "`S2item'"=="" local SMerrs = "`SMerrs' `var'"		  // If S2item isnt linked, extend list of unlinked SMvars
		else  local gotSMvars = "`gotSMvars' `var'"		  		  // Else extend list of linked SMvars
			
		
		if "`SMerrs'"!=""  {									  // If there are any unlinked SMvars
		
		   display as error "SMvar(s) without active link(s) to (existing) variable(s): `SMerrs'"
*					         12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   if wordcount("`SMerrs'") == 1  {  
			  errexit "stackMe quasi-var `SMerrs' has no active link to an existing variable"
			  exit 1
		   }													  // Else we have two vars without active links
		   else  {
		   	errexit "stackMe quasi-vars `SMerrs' have no active links to existing vars; will exit on 'OK'"
			exit 1
		   }
		   
																  // If we reach this point we have links to check
		   foreach var of local gotSMvars	{					  // Cycle thru (up to) 2 vars in 'gotSMvars'
		      capture unab var : `var'				  			  // See if these linked vars exist
			  if _rc  {											  // If link does not access an existing variable
			  	 local SMbadlnk = "`SMbadlnk' `var'"			  // Add that quasi-var to 'SMbadlnk'
			  }
		   } //next 'var'
		   
		   if "`SMbadlnk'"!="" {								  // If 'SMnolnk' is not empty
			  errexit "Quasi-vars with broken links (linked vars don't exist): `SMbadlnk'"
			  exit 1
		   }													  // 'errexit' is a subprogram listed later in this ado file
		}
		
		if "`gotSMvars'"!=""  return local gotSMvars `gotSMvars'
														
end checkSM







capture program drop checkvars
		
program checkvars, rclass						// Checks for valid input/outcome vars. Partially overcomes intermittant
												//  error when unab is presented with a hyphentated list of varnames
												// (with hyphentd AND non-hyphenated it can wrongly send non-zero return code)
												// ("partially" because 'unab' exits on first bad varname it finds, whereas
												//	the whole point of this subprogram is to build a list of all bad varnames)

	args check													// Argument 'check' has list of non-'unab'ed variables	
																// (may include hyphenated varlist(s))
																// (returns unabbreviated un-hyphenated vars in r(check))
																
		local checked : list uniq check							// Remove any duplicates; then check validity
																//				   of each var and hyphenated varlist 
		local errlst = ""										// List of invalid vars and invalid hyphenatd varlsts
		local strerr = ""										// Arg for 'errexit' holds (first) bad hyphenated varlist 
		
		local check = strtrim(stritrim("`checked'"))			// Eliminate extra blanks around or within 'check'
		
		if strpos("`check'","-")==0  {							// If there are no hyphenated varlists
		  foreach var of local check  {							// Cycle thru un-hyphenated vars in varlist
			capture unab var : `var'							// If 0 not returned variable does not exist
			if _rc  local errlst = "`errlst' var"				// So add that invalid var to 'errlst'
		  }
		}
		
		else  {													// Else there are one or more hyphenated varlists
		
		  local chklist = "`check'"								// Want to keep 'check' untouched for SM search, below
																
		  while strpos("`chklist'","-") >0  {					// While there is an(other) unexpanded varlist in 'chklist'
																// (chklist has 'head' to 'test2' removed at end of 'while')
			local loc = strpos("`chklist'","-")					// Find loc of hyphen that defines the list
			local head = substr("`chklist'",1,`loc'-1) 			// Extract string preceeding hyphen
			local test1 = word("`head'",-1)						// Extract last word in 'head' (word before hyphen)
			local tail = substr("`chklist'",`loc'+1, .)			// Extract string followng hyphen (may contain another "-")
			local test2 = word("`tail'",1)						// Extract the 1-word varname following the hyphen
			
			local t1loc = strpos("`chklist'","`test1'")			// Get loc of first word in hypnenated varlist
			if `t1loc'>1  {										// If there are vars before 'test1', evaluate those
			   local pret1 = substr("`chklist'",1,`t1loc'-1)	// These vars end before 'test1'; put them in 'pret1'
			   foreach var of local pret1  {					// And evaluate each one
			   	  capture unab var : `var'						// If 0 not returned...
				  if _rc  local errlst = "`errlst' `var"		// Add any invalid varnames to 'errlst'
			   }
			}													// 'test3' will be string "'test1'-'test2'" inclusive
			local t3len = strlen("`test1'")+strlen("`test2'")+1	// Get full length of string 'test1' to end of `test2'
			local test3 = substr("`chklist'",`t1loc',`t3len') 	// String them together as when embedded in 'chklist'
			
			capture unab test3 : `test3'						// (test3 starts w 'test1' & ends w end of word after "-")
			if _rc  {											// If 0 not returned 'test3' has at least one non-variable
			  if "`errlst'"!=""  continue, break				// If already have bad varnames, report those on this run
			  local errlst = "`test3'"							// (this error will show up on next run, if not fixed)
			  local strerr = "unab test3 : `test3'"				// 'strerr' holds cmd that found FIRST bad hyphenated list
			  continue, break									// (which is all that can be reported, so exit loop)
			}													// Stata will identify (first) invalid varmame on 'errexit'
																// (later errors cause errexit if found by 'unab', above)
			
			local chklist = substr("`chklist'",`t1loc'+`t3len'+1,.) // Strip all up to end of 'test3' from head of chklist
			
			if "`strerr'"!="" &  strpos("`chklist'","-")>0  continue, break	// If there is ANOTHER "-", skip rest of while 
																// (Cannot report more than one 'unab' error)
	
			if "`chklist'"!="" {								// Else if there are more vars in 'chklist'
			   foreach var of local chklist  {					// Check that each of them is valid
			   	 capture unab var : `var'
				 if _rc  local errlst = "`errlst' `var'"		// If 0 not returned add any invalid vars to 'errlst'
			   }
			}
			
		  } //next hyphen										// See if there are any more hyphens
		  
		} //endelse												// End of codeblock dealing with hyphated varlist(s)
		
								
		if "`errlst'"!=""  {									// If any bad varnames were identiried ...
		  if "`strerr'"!=""  {									// If a bad 'unab' was also identified ...
			errexit "Invalid variable name(s) among: `errvars'; Stata will amplify after 'OK'"  "`strerr'"
			exit 1
		  }														// Call on 'errexit' reports msg then causes same error
																// (so Stata will identify the offending varname)
		  else  {
		  	errexit "Invalid variable name(s): `errvars'"		// Lack of `strerr' arg means 'errexit' will just report
			exit 1
		  }
		}														// ('errexit' will exit w display and optional Stata msg)
																// (Stata msg produced by tryng to unab 'test3' if supplied)
	return local checked `check'								// Return unabbreviated un-hyphenated vars in r(checked)
	
end checkvars










capture program drop errexit

program define errexit							// THIS ERROR-REPORTING SUBPROGRAM WAS DESIGNED AS TWO SUBPROGRAMS IN ONE. IF subprogname
												// IS FOLLOWED BY COMMA, errexit PARSES THE OPTIONS; ELSE LOOKS FOR 1 OR 2 ARGUMENTS.
												// FIRST ARG OR OPT IS ALWAYS MSG TO BE SENT TO STOPBOX. IF IT COMES AS AN ARG IT IS
												// ALSO DISPLAYED IN RESULTS WINDOW AND, IF FOLLOWED BY ANOTHER STRING, 2ND STRING IS 
												// PROCESSED AS A STATA ERROR (in two different ways, depending on type).
												//   IF STRINGS COME AS OPTIONS, errexit EXPECTS PRIOR DISPLAY BY CODEBLK THAT DIAG-
												// NOSED THE ERROR AND, IF FOLLOWED BY OPTION `origdta', RESTORES ORIGINAL DATA PRIOR
												// TO EXIT, USING `origdta' AS THE TEMPFILE HOLDING THE DATA TO BE RESTORED.
												// (complexity is 'cos of need to handle legacy code using two arguments)

*	gettoken head rest : "`0'"					// Get first word of string sent to this subprogram (overcomes quote problems)
	if "`1'"==","  {							// If what was sent to 'errexit' starts with a comma then it handles all possibilities
*	if substr(strtrim("`head"),1,1) == ","  { 	// NOTE: 'msg' is always sent to stopbox, no matter how it was acquired or optioned
	   local display = ""						// 'msg' will only be displayed if optiond; origdta will be restored if optioned
	   syntax , [ MSG(string) ORIgdta(string) STAtaerror(string) DISplay] *	
	}											// (and optional `stataerror' is Stata return code or string that caused the error
	
	else  {										
	   local display = "display"				// Else there is no comma, so 'msg' argument is for stopbox AND for Results window
	   args msg stataerror						// First arg is `msg' to display; 2nd is optional Stata return code, if numeric; else
	}											//  optional 'stataerror' holds the command-line string responsible for the error
	
	if "`origdta'"!=""  {						// If name of tempfile was provided, first restore and use the original dataset
		capture restore							// ('capture' added in case data are not preserved)
		quietly use `origdta', clear			// Here restore 'origdta' dataset
	}
	
	if "`stataerror'"!=""  {					// If errexit was called by stackMe program with knowledge of Stata error..
		capture confirm number `stataerror' 
		if _rc  local msg = "Stata reports likely data error in $errloc"  // Not numeric so likely an 'unab' error (addressed below)
		else  local msg = "Stata reports likely program error `stataerror' in $errloc" // Numeric so likely a captured return code
		display as error "msg"
	} //endif
	
	else if "`display'"!="" display as err "`msg'" // Else, with no stata error, display the supplied 'msg' whether argument or optd
												// (note that display might be optioned or might be inherent if it was an argument)
												// Since we exit we must drop all globals, which yields a tricky problem addressed...
	scalar SMstataerror = "`stataerror'"		// Save in a scalar the stataerror argument
	scalar SMmsg = "`msg'"						// Save in a scalar the 'msg' argument or option
	scalar filename = "$filename'"				// Save, in a scalar, global filename – relevant for later stackMe cmds
	scalar dirpath = "$dirpath"					// Ditto for $dirpath
	scalar exit = "$exit"						// Ditto for $exit
	scalar multivarlst = "$multivarlst"			// Ditto for $multivarlst
	macro drop _all								// Clear all macros before exit (evidently including the above two)
	local stataerror = SMstataerror				// A local will be dropped automatically on exit
	local msg = SMmsg							// Ditto
	global filename = filename				    // But filename may be useful for later 'stackme' commands
	global dirpath = dirpath					// Ditto for dirpath
	global exit = exit							// Ditto for $exit
	global multivarlst = multivarlst			// Ditto for $multivarlst

	scalar drop SMstataerror SMmsg filename dirpath exit multivarlst // Must overtly drop scalars used to secure those loc/globals
	
	global SMreport = "reported"				// Flag to avert duplicate report from calling program
	
	if "`stataerror'"!=""  {					// See if there was a stataerror optioned
	   capture confirm number `stataerror'		// If so, see if it was numeric
	   if _rc   `stataerror'					// If not numeric use the string to replicate the offending command, without capture
	   else  exit `stataerror'					// Else exit with the offending return code
	}
					
	else  {										// Else `stataerror' is empty so error was diagnosed at source and reported above
	   window stopbox stop "`msg'; will exit on 'OK'" // Sometimes exits directly; sometimes returns to program as above
	} 											// (NEED TO RESEARCH THIS)															***
	
	
end errexit






capture program drop getwtvars

program define getwtvars, rclass
										// Identify and save weight variable(s), if present, to be kept in working dta
global errloc "getwtvars"

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
		  	errexit "Clarify weight expression: use (perhaps parenthesized) varname at start or end"
			exit 1
		  }
		  
		} //endif 'wtexp'
		
		return local wtvars `keepv'

end getwtvars







capture program drop isnewvar								// Now called from wrapper (NO LONGER CALLED FROM gendist in VERSION 2)

program isnewvar											// New vars all have prefixes 

global errloc "isnewvar"

	version 9.0
	syntax anything, prefix(string)
	
	if "`prefix'"=="null"  local prefix = ""				// No prefix will be prepended to anything-var if prefix is "null"
	
	local ncheck : list sizeof anything						// 'anything' may have several varnames
	
	forvalues i = 1/`ncheck'  {								// anything already has default prefix for each var
	
	  local var = word("`anything'",`i')
	  if "`prefix'"!=""  local var = "`prefix'_`var'"		// If a(n additional) prefix was optioned (eg in gendummies)..
	  capture confirm variable `var'						// These vars are default-prefixed; optional changes not yet made
	  if _rc==0  {											
	    global prefixedvars = "$prefixedvars `var'"			// Add to global without revising prefix to optioned prefixstring
		global exists = "$exists `var'"						// ($prefixedvars is list of existing vars with that prefix)
	  }
	  else global newprfxdvars = "$newprfxdvars `var'"		// List of prefixed outcome vars
	  local prfx = strupper(substr("`var'",1,2))			// Extract prefix from head of 'var' & change to upper case
	  local badvar = "`prfx'"+substr("`var'",3,.)			// Potential badvar has upper case prefix
	  capture confirm variable `badvar'						// See if uppercase version is left over from previous error exit
	  if _rc==0  {
	  	global badvars = "$badvars `badvar'"				// If so, add to list of such vars
	  }
	  
	} //next var
		
	
end //isnewvar








capture program drop showdiag1

program define showdiag1

global errloc "showdiag1"

args limitdiag c nc 	
		   

				   local vartest = "$keepvars"		

				   local vartest = subinstr("`vartest'",".","",.)	  // Remove any missing-symbols (DK where they come from)
				   unab vartest : `vartest'	

				   local test : list uniq vartest					  // Strip any duplicates of vars in vartest; put result in 'test'
				   local nvars = wordcount("`test'")
				   scalar minN = .									  // (a big number)
				   scalar maxN = -999999

				   global noobsvarlst = ""							  // Local will hold list of vars with no obs in this context
				   
				   foreach var of local test  {					  	  // For each var in 'vartest' (now 'test')
						
						tempvar misvar count						  // Create temporary vars to count N of missing
						qui gen `misvar' = missing(`var')			  // Code mis'var' =0, or =1 if missing
						qui capture count if ! `misvar'				  // Unless error, yields r(N)==0 if var does not exist
						local rN = r(N)
						local rc = _rc								  // Place command in left margin because of how it prints
if `rc' display `rc'
					    if `rc' & `rc'!=2000  {						  // If non-zero return code which is not 'no obs'
							global exit = 1							  // use $exit=1 'cos we must restore origdata before exit
							continue, break							  //  origdta before exiting (NOTE $exit=1 is not 'exit 1')
						}
						if `rN'==0  {								  // If there are no non-miss obs for this var in this context
						   global noobsvarlst = "$noobsvarlst `var'"  // Store any vars with no obs 
						}
						else {										  // Else, if vars were not flagged as all-missing
						   if `rN'<minN  scalar minN = `rN'		  	  // Update _N min and max scalar values for max & min Ns
						   if `rN'>maxN  scalar maxN = `rN'			  // Scalars can be accessed from showdiag2
						}
						quietly capture drop `misvar' 				  // Drop these two vars
						quietly capture drop `count'
						
				   } //next var
					  
				   if $exit  continue, break
				   
				   if !$exit  {								  		  // Only execute this codeblk if an error has not called for exit 
				      if `rc'!=0 & `rc'!=2000 {						  // If there was a diffrnt error in any 'count' command
						 local lbl : label lname `c'				  // Get the context id
					     errexit "Stata has flagged error `rc' in context `lbl'"
					     exit 1										  // Set flag for wrapper to exit after restoring origdata
				      }
				   
					} //endif !$exit

end showdiag1








capture program drop showdiag2

program define showdiag2

global errloc "showdiag2"

args limitdiag c nc xtra

			
			if `nc'>1  local multiCntxt = 1							  // Different text for each context than whole dataset
			else local multiCntxt = 0
	
			local numobs = _N										  // Here collect diagnostics for each context 
				   					  
			if `limitdiag'>=`c' & "$cmd'="!="geniimpute" {			  // `c' is updated for each different stack & context
								   
				local lbl : label lname `c'							  // Get label for this combination of contexts
					  
				local lbl = "Context `lbl'"							  // Below we expand what will be displayed
					  
				if ! `multiCntxt' {
					local lbl = "This dataset"
					if "cmd'"=="genstacks"  local lbl = "This dataset now" 
				}													  // Only for 'genstacks' referring to stacked data
					  
				local newline = "_newline"
				if "$cmd"=="genstacks" local newline = ""
*				noisily display "   `lbl' has `numobs' observations{txt}" _newline
					  
				capture confirm variable SMstkid					 // See if data are stacked
				if _rc==0  local stkd = 1
				else local stkd = 0
				
				local displ = 0
				if `stkd' {
					if SMstkid == 1  {							 	 // By default, if stkd, give diagnsts only for 1st stack
					   if `multiCntxt' & "$cmd"!="geniimpute" {		 // Geniimpute has its own diagnostics   
					   	  local displ = 1`			
						}
					}
				}
				
				else {												 // Else dataset is not stacked
					if `multiCntxt' & "$cmd"!="geniimpute" {		 // Geniimpute has its own diagnostics  			
						local displ = 1
					}
				}
				
				if `displ'  {
				   local msg = "   `lbl' has `numobs' observations"
				   showmsg  "`msg'" 								 // Noisily display the msg

				   if `xtra'  {									 	 // If 'extradiag' was optiond, also for other stacks
					  local other = "Relevant vars "				 // Resulting re-labeling occurs with next display
					  if "$noobsvarlst"!=""  {
						local errtxt = ""
						local nwrds = wordcount("$noobsvarlst")
						local word1 = word("$noobsvarlst", 1)
						local wordl = word("$noobsvarlst", -1)		 // Last word is numbered -1 ('worl' ends w lower L)
						if `nwrds'>2  {
							local word2 = word("$noobsvarlst", 2)
							local errtxt = "`word2'...`wordl'"
							if `nwrds'==2 local errtxt = "`wordl'"
							if `xtra' noisily showmsg "NOTE: No observations for var(s) `word1' `errtxt' in `lbl'"
							local other = "Other vars "				 // Ditto
						}
					  }
					  
					  local minN = minN							 	 // Make local copy of scalar minN (set in showdiag1)
					  local maxN = maxN								 // Ditto for maxN
					  local lbl : label lname `c'
					  local newline = "_newline"
					  if "$cmd"=="genstacks" local newline = ""
					  
					  if `multiCntxt'  noisily showmsg 				/// geniimpute displays its own diags
						 "`other'in context `lbl' have between `minN' and `maxN' valid obs"
						 
*					  noisily display "{txt}" _continue

				   } //endif 'xtra'
				
				} //endif 'displ'
						 
			} //endif 'limitdiag'

			else  {													// If limitdiag IS in effect, print busy-dots
		  
			  if `limitdiag'<`c'  {									// Only if `c'>= number of contexts set by 'limitdiag'
					if "`multiCntxt'"!= ""  {						// If there ARE multiple contexts (ie not gendummies)
						if `nc'<38  showmsg ".." _continue			// (more if # of contexts is less)
						else  showmsg "." _continue					// Halve the N of busy-dots if would more than fill a line
					}
			  } //endif
				
			} //endelse

			if `c'==`nc'  capture scalar drop minN maxN				// If this is the final context, drop scalars
			
end showdiag2







capture program drop showmsg

program define showmsg										// Attempted way around displays that are not displayed

args msg aserr												// 'msg' will 'display as error' if option 'aserr' is not empty

	while strlen("`msg'") > 80  {							// If 'msg' is longer than can fit on one line of results window
		local lastspace = strrpos("`msg'", " ")				// Find last space in 'msg'
		local line = substr("`msg'",1,`lastspace'-1)		// Use that to delimit end of line
		if "`aserr'"!=""  display as error "`line'{txt}"	// Display as error if msg was accompanied by non-blank second arg
		else  noisily display "`line'"						// Else just display it noisily
		local msg = substr("`msg'", `lastspace'+1, .)		// Replace 'msg' with remainng msg chars, starting at 'lastspace'+1
	}														// Exit 'while' loop when less than 80 chars are left
	
	if "`aserr'"!=""  display as error "`msg'"				// Display (remaining) chars in 'msg', either 'as error' or noisily
	else  noisily display "`msg'"
	
end showmsg








capture program drop stubsImpliedByVars

program define stubsImpliedByVars, rclass		// Subprogram produces a list of stubs corresponding to multiple varlists

global errloc "stubsImpliedByVars"

	local stubslist = ""										// Will hold suffix-free pipes-free copy of what user typed
				
	local postpipes = "`0'"										// Pretend what user typed started with "||", now stripped
	
	while "`postpipes'"!=""  {									// While there is anything left in what user typed
	
	   gettoken prepipes postpipes : postpipes, parse("||")		// Get all up to "||", if any, or end of commandline
	   if substr(strtrim("`postpipes'"),1,2)=="||"  {			// If (trimmed) postpipes starts with (more) pipes
		  local postpipes = substr("`postpipes'",3,.)			// Strip them from head of postpipes
	   }
	   
	   unab vars : `prepipes'									// Stata will report an error if not valid vars
	   
	   local 0 = "`vars'"										// Pretend user typed only one varlist; put back in '0'

	   syntax namelist(name=keep)								// Put names into local 'keep'
	   
	   local stlist = ""										// Stublist derived from this one varlist
	
	   while "`keep'"!=""  {
		  gettoken s keep : keep								// 's' is each word in 'keep', one at a time
		  while real(substr("`s'",-1,1))<.  {					// While last char is numeric
			local s = substr("`s'",1,strlen("`s'")-1)  			// Shorten `s' by one trailing numeral
		  }
		  local stlist = "`stlist' `s'"							// `stlist' is copy of keep, but shorn of suffixes
	   } //next `keep'											// (and cumulating across successive varlists)
	  				  
					  
	   local stub = ""											// Will hold the unique stub from stlist
	   local w1 = word("`stlist'",1)							// Start with first stub in 'stlist'
	   
	   while "`stlist'"!=""	{									// So long as there are any stubs left in stlist ...
		  while "`w1'" == word("`stlist'",1)  {					// While next word in `stubslist' remains the same ...
			gettoken w1 stlist : stlist							// Move successive stubs into `w1'							
		  } 													// Exit this loop when `stlist' has no more w1 stubs
		  local stub = "`w1'"	 								// Final copy of `w1' is the stubname for this varlist
																// (need to save in a local that will persist ouside loop)
		  if "`stlist'"!="" {
			errexit "Variables in battery do not all have same stub: `stlist'"
			exit 1
		  }														// Error exit if next stub belongs to a different varlist						
	   } //next while "`stlist'"								// Exit this loop when `stlist' has no more stubs
	   
	   local stubslist = "`stubslist' `stub'"					// Append to stub
	   
	} //next pipes
	
	return local stubs `stubslist'								// Put accumulated stubs into r(stubs)

																	
end stubsImpliedByVars






	
	
capture program drop subinoptarg

program define subinoptarg, rclass					// Program to remove supposed vars from varlist if they prove to be strings
													// or for other reasons (MAY NOT BE CALLED)
global errloc "subinoptarg"

syntax , options(string) optname(string) newarg(string) ok(string)


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
		if "`ok'"==""  {
			errexit "optname not found"							// Programming error
			exit 1
		}
	}
	return local options `options'

end subinoptarg








capture program drop varsImpliedByStubs

program define varsImpliedByStubs, rclass		// Subprogram converts list of variable stubnames to a list of vars implied 
												// (eliminating false positives with longer stubs)
global errloc "varsImpliedByStubs"

	syntax namelist(name=keep)
	
	if strpos("`keep'","||")>0  {
		errexit "Stublist should not contain '||'"
		exit 1													// Ensure stublist has no pipes
	}
	
	local varlist = ""											// Accumulating list of vars implied by each stub in turn
	local keepv = ""											// Accumulating list of vars verified as having numeric suffix
	local nstubs = wordcount("`keep'")
	
	forvalues h = 1/`nstubs'  {									// We know that `keep' was filled with stubs by caller 
	
		gettoken k keep : keep									// Repeatedly peel off first word of `keep' (list of stubnames)
		local lenstub = strlen("`k'")							// Get # of chars in stub
		capture unab vars : `k'*								// Get list of vars with this stub 
		
												
											// LIST MIGHT INCLUDE ADDITIONAL VARS WITH LONGER STUBS; DON'T ADD THOSE TO 'keepv'
		foreach var of varlist `vars'  {
			local suffix = substr("`var'",`lenstub'+1,.)		// Abstract the suffix for each var
			capture confirm integer number `suffix'				// See if whole suffix is an integer number
			if !_rc  {  										// If return code is zero ..
				local keepv = "`keepv' `var'"					// Append var to varlist if its whole suffix is numeric
			}
		} //next 'var'
		
	} //next stub
	
	return local keepv `keepv'

	
end varsImpliedByStubs




************************************************ END SUBROUTINES *****************************************************



