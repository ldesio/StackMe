

capture program drop stackmeWrapper

*!  This ado file is called from each stackMe command-specific caller program and contains program 'stackmeWrapper' that forwards calls
*!  onward to `cmd'O and `cmd'P subprograms, where `cmd' names a stackMe command. This wrapper program also calls on various subprograms
*!  meant primarily to reduce the complexity of wrapper codeblocks. Those include 'varsImpliedByStubs' 'checkvars' and 'errexit', among
*!  others, whose code is appended following the code for 'stackmeWrapper'. Additional subprograms – so-called "utility programs" – can 
*!  be found in an ado file named 'stackMe.ado'. Several of these ('SMsetcontexts' 'SMfilename' and 'SMitemvars') can be directly invoked
*!  by users, but such usage should be rare except for the required user-invocation of the 'SMsetcontexts' utility program, which should  
*!  be the first stackMe command invoked by a user intending to employ any dataset with stackMe for the first time. See the helpfile for
*!  'help stackMe' that should be required browsing for anyone hoping to make sense of the codeblocks that follow.

*!  Version 4 replicates normal Stata syntax on every varlist of a v.2 commnd (eliminates previous cumulation of optns across varlsts)
*!  Version 5 simplifies version 4 by limiting positioning of ifin expressions to 1st varlist and options to last varlist,
*!  Version 6 implements 'SMsetcontexts' and the experimental movement of all preliminary 'genplace' code to 'genplaceO'.
*!  Version 7 revives and improves code from Version 3 that tried to identify the actual variable(s) employed in a weight expression.
*!  Version 8 moves to new `cmd'O programs additional "opening" codeblocks, from 'gendist', 'geniimpute', and 'genstacks'. 
*!  Version 9 introduces $varlist, $prfxvar, $prfxstr globals so `cmd'P programs need not do so; option to evaluate simpler append code.
*!			  (simpler append code uses file with accumulating contexts and appends current context to that file – seemingly slower!)
 
*!  Stata version 9.0; stackmeWrapper versions 4-9 updatd Apr, Aug '23 & again Apr '24 to May'25 by Mark from major re-write in June'22

*!  AT SOME POINT INVESTIVATE USE OF STATA COMMAND 'snapshot' IN LIEU OF 'preserve' SO stackMe WILL WORK ON PRESERVED DATA.				***

										// For a detailed introduction to the data-preparation objectives of the stackMe package, 
										// see 'help stackme'.

program define stackmeWrapper	  		// A "wrapper" called by `cmd'.ado (the ado file named for any user-invoked stackMe command) 

scalar save0 = "`0'"					// Save 2 existing macros of relevance to this invocation of 'stackmeWrapper' (see below).
scalar pauseon = "$PAUSEON"
										// This wrapper calls `cmd'O, once each, for several commands and then repeatedly calls `cmd'P
										// (the program doing the heavy lifting for that command) where context-specific processing
										// generally takes place, one context per call on `cmd'P. The wrapper also parses the user- 
										// supplied stackMe command line, reduces the active data to user-named/implied variables and 
										// sets up options and varlist(s) for calls on `cmd'O and `cmd'P. It then manages the accumula-
										// tion of files, one for each context, and merges those files with the original datafile before
										// calling on subprogram 'cleanup' to post-process the outcome data as per user-specified
										// options before returning execution to the original calling program, which exits Stata. 
										
										// This complex structure fulfills the design goals to (1) access each data observation the 
										// minimum possible number of times per stackMe operation and (2) have the same code provide any 
										// service requied by all stackMe commands, simplifying program maintenance and error-correction.
*		********						
* 		Summary:						// Wrapper for stackMe version 2.0, June 2022, updated in '23, '24 & '25. Version 8 extracts 
*		********						// working data (variables and observations determined by each stackMe command-line) before  
										// making (generally multiple) calls on `cmd'P', once for each context and (generally) stack. 
										// These multiple calls avoid the need to evaluate an 'if' expression separately for each 
										// observation, greatly reducing processing time. Processing time is also economised by 
										// processing multiple varlists on a single pass through the data. 
										
										// Processed data for each context-stack is progressively appended to a separate file from 
										// which it is merged back into the working data when all contexts have been processed. Care 
										// is taken to restore the original data before terminating execution after any anticipated
										// error. (Unanticipated errors are also captured and original data restored so that the user 
										// is not confronted with a working dataset consisting of only a single context and stack). 
										// Anticipated errors that are displayed as "program error" are not really anticipated and 
										// should be reported to the authors, along with a copy of the command-line responsible.
*		*******							
* 		Syntax:							// General syntax: << cmd varlst [ifin] [wt] [ || varlst [wt] ||...|| varlst [wt] ], optns>> 
*		*******							// Varlist syntax: << [str_] [prefixvars :] varlist [ifin][wt] >>
										
										// With this general syntax, an initial string (a prefix for labeling outcome variables) can 
										// only occur before a prefixvar(list); 'ifin' must follow the first varlist; 'options' must 
										// follow the last varlist; 'weight's can follow any varlist. These variations reduce to a 
										// standard Stata command line: << cmd varlst [ifin] [wt], options' >>, as shown above. With 
										// this second (more traditional) syntax, prefixvars and their preliminary strings become 
										// additional options.
*		**********						
* 		Structure:						// StackMe commands are not totally uniform in their structure or data requirements, so this 
*		**********						// wrapper program contains codeblocks that are specific to particular stackMe commnds. But 
										// the general structure of the wrapper, as embedded in the entire stackMe package, follows...
										
										// 0. Invoke appreviated caller (e.g. 'gendi', if invoked) to call the actual calling program 
										// (e,g, 'gendist', which can also be invoked directly). There construct an 'options mask' 
										// from which a syntax command will be derived in 'stackmeWrapper', the common ado file that
										// parses the command lines for all stackMe commands and governs the ensuing path taken in
										// order to fulfil each command, as follows...
										//
										// 1. Parse the syntax, separate varlists from options, parse the options, extract a list of 
										// vars needed by those options that must be included in context-specific working dta (this
										// takes a suprising amount of code). From each input varlist, extract the names that will 
										// govern the construction of outcome variable names. On the basis of these two lists, form 
										// a combined list uniquely identifying the variables to be retained in working dta. As far
										// as possible ensure that the names of variables to be created do not duplicate any existing
										// names (warn users of possible ensuing name conflicts if these can't be prevented).
										//
										// 2. Save the original datafile for later merging with genereted variables; drop variables 
										// and oservations not needed in the working data; conduct preliminary checks for anticipated 
										// likely errors in the current 'cmd'P; often invoke a preliminary 'cmd'O (for 'open') – a
										// subprogram that performs preliminary processing that requires access to all observations  
										// in the dataset – before repeatedly invoking `cmd'P (for program), once for each context.
										//
										// 3. For each context (e.g. country-year-stack), preserve the working dataset and drop from 
										// the active data all contexts other than the currently active context (generlly stack-within
										// context but context-level for 'genstacks' and 'genplace'); invoke 'cmd'P (for program) that
										// does the heavy lifting, transforming input vars into appropriately-processed outcome vars.
										//
										// 4. Store processed data for each context in a separate file. When all contexts have been
										// processed append each of those separate files to the first of them (the file on which the
										// full dataset is built); delete each of the tempfiles after appending. Finally merge the 
										// complete file of working data back into the original dataset (all new vars have new names,
										// generally constructed by prepending a prefix or adding a suffix to the original name).
										//
										// 5. Save working subset in a single tempfile that, after the first context (whose outcome
										// data is saved as foundation), is appended to the growing tempfile of outcome data; restore 
										// the original dataset, mentioned in 2, above, and merge it with the tempfile of outcome data
										// from 3, above; report (if optioned) on missing observations per context and overall.
										// 
										// 6. Return execution to the original calling program where variables are renamed and other-
										// wise post-processed or dropped, as optioned, and Stata errors captured.
										//
										//			  Lines suspected of still proving problematic are flagged in right margin      	***
										//			  Lines needing customizing to specific `cmd's are flagged in right margin    	 	 **

										
*		************************		// Commands framed by asterisks play a critical role in defining stackMe package structure
*		commands to look out for		// (see examples to left). Comments framed in the same manner explicate features of stackMe
*		************************		// package structure.
									
									
*		************************		
		macro drop _all					// Global flags, etc., may have remained active on earlier error exit, so this cmd is issued
		global save0 = save0			// here – the earliest point where all stackMe commands share the same lines of program code.
		global PAUSEON = pauseon		// We don't want this turned off at start of every stacmMe command ('save0' & 'pauson' are 
		scalar drop _all				// scalars set at top of left-hand column; similar scalar useage is seen in program 'errexit'
*		************************		// and in final codeblock of each caller program.
		capture drop ___*				// Drop quasi-temporary variables used to deal with name conflicts, remaining after error exit
										
										
*		**************************		// Used by subprogram 'errexit' where un-anticipated Stata-reported non-zero return codes are 
		global errloc "wrapper(0)"		// sent when captured. Global errloc stores a string that roughly identifies likely locations
*		**************************		// for any error. User errors are handled more specifically in the codeblocks where such errors
										// are identified; but even these (ultimately) yield a call on subprogram 'errexit' (appended), 
										// which restores the original data (if changed by the time the error is identified).
										
*		******************
*		Coding conventions				// Several coding conventions used in stackMe programs are commonly used to ease code comprehen-  
*		******************				// sion; a less common convention is to put command names and command strings within standard  
										// single quotes (''), to distinguish them from names of locals, placed within Stata-defined 
										// single quotes (`') where this helps comprehension; but this convention is unfortunately not   
										// ubiquitous (since it was adopted late in the coding process).
										
*****************
capture noisily {						// Here is the opening brace of a capture that encloses remaining wrapper code, except for a
*****************						// final codeblock that processes any captured errors. (That codeblk follows the close brace 
										// that ends the span of code within which errors are captured).

										// *******************************************************************************************
*capture noisily {						// This command is a cluge to prevent the matching close-brace (blk 11) from flagging an error
										// *******************************************************************************************
										
										
										//		********************************************************************************
pause (0)								// (0)  Preliminary codeblock establishes name of latest data file used or saved by any 
										// 		Stata command and other globals needed throughout stackmeWrapper. Further 
										//		initialization of a large number of locals is documented at start of codeblk (2)
										//		********************************************************************************
										
	global multivarlst = ""									// Global will hold copy of local 'multivarlst' for use by caller progs
															// (holds list of varlsts typed by user, includng ":", separatd by "||")
	global keepvars = ""									// As above, but with dups & separatrs removd, & addtnl optiond varnames
	global SMreport = ""									// Signals error msg already reportd, to 'errexit' and to calling progrms.
	global exit = 0											// Signals to wrapper the current state of data usage:
															// $exit==1 requires restoration of origdta; $exit==0 or $exit==2 doesn't
															// ('exit 1' is a commnd –sets return code 1–  $exit=1 is flag for caller)
	global nvarlst = 0										// N of varlists on commnd line is initialized to 0 (updatd by `nvarlst')

	local filename : char _dta[filename]					// Get established filename if already set as dta characteristic

	if "`filename'"==""  {
	
		display as error //
		"This datafile should be initialized by {help SMutilities##SMsetcontexts:{ul:SMset}textvars} for use by {bf:stackMe}"

		window stopbox stop "This datafile has not been initialized by 'SMsetcontexts' for use by 'stackMe' – see displayed message"

	} //endif filename										// Need user to read help text before starting!
	
	capture confirm variable SMstkid						// See if dataset is already stacked
	if _rc  local SMstkid = ""								// `SMstkid' holds varname "SMstkid" or indicates its absence if empty
															// (will be replaced by local 'stackid' after checking that not optioned)
	else  {													// Else there IS a variable named SMstkid
	  local SMskid = "SMstkid"								// Record name of stackid in local stackid (always 'SMstkid', if any)
	  capture confirm variable S2stkid						// See if dataset is already double-stacked
	  if _rc  {			
		local dblystkd = ""									// if not, empty the indicator
		gettoken prefix rest: filename, parse("_") 			// And check for correct prefix to filename
		if "`prefix'"!="STKD" & "`prefix'"!="S2KD"  {
		  window stopbox note "Dataset with SMstkid variable should have filename with STKD_ (or S2KD_) prefix"
*                  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		  local warnexit = "warn"							// Need to warn of implications before exit (alternative path)
		  
		}
	  } //endif _rc
	  
	  else  {
	  	local dblystkd = "dblystkd" 						// Else _rc of 0 shows data are doubly-stacked
		gettoken prefix rest: filename, parse("_") 			// And check for correct prefix to filename

		if `prefix'!="S2KD" {
		  window stopbox note "Dataset with S2kid variable should have filename with S2KD_ prefix"
		  local warnexit = "warn"							// Need to warn of implications before exit (alternative path)
		}	  
	  }														// – 'genstacks' is caller that brought us here – has no access to locals)
	} //endelse
	
	if "`warnexit'"!=""  {									// This warning applies to both of two possible error msgs, above
		display as error "Bad file configuration; see help {help stackMe} for suggested stackMe workflow"
*                  		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		errexit, msg("See stackMe helpfile for suggested stackMe workflow")
		exit												// Exit to calling program after exit from 'errexit'
	}
		
	global dblystkd = "`dblystkd'"							// And make a global copy accessible to other programs (e.g. 'genstacks')
															// (local `dblydtkd' may be empty)

	local multivarlst = ""									// Local will hold (list of) varlist(s) (also provide it to $multivarlst)
	local noweight = "noweight"								// Default setting assumes no weight expression appended to any varlist
	
	local needopts = 1										// MOST COMMANDS NEED OPTIONS-LIST (exceptns are ON 3rd line of codeblk 0.1)
	
	

	
	
	
global errloc "wrapper(0.1)"
pause (0.1)	


										//		 ************************************************************************************
										// (0.1) Codeblock to pre-process the command-line passed from `cmd', the calling program.
										//       It divides up that line into its basic components: `cmd' (the stackMe commend name);
										//	    `anything' (the combined varlist/namelist and ifinwt expression); the comma followed 
										//	     by `options' appended to that expression; the syntax `mask' appended to the above;  
										//	     and two afterthoughts that are placed between the options and the mask.
										//		 *************************************************************************************

										
	gettoken cmd rest : (global) save0						// Get the command name from head of global save0 (what the user typed)
															// (saved in global save0 after 'commands to look out for', above)
															// (gettoken primes local `rest' for the next 'gettoken', below
	global cmd = "`cmd'"									//  and provides a global accessible from other programs)

	if "`cmd'"=="gendummies" | "`cmd'"=="genmeanstats" local needopts = 0 // These two stackMe commands do not require an options-list
															// ADD ANY OTHER EXCEPTIONS, AS DISCOVERED 									***
	gettoken cmdstr mask : rest, parse("\")					// Split rest' into the command string and the syntax mask
						
	gettoken preopt rest : cmdstr, parse(",")				// Locate start of option-string within 'cmdstr' (it follows a comma)
															// ('preopt' will be prepended to 'postopt', below, to make 'multivarlst)
	if "`rest'"!=""  local rest = substr("`rest'",2,.) 		// Strip off "," that heads the mask ('if' clause should redundant)
	if strpos("`rest'",",")>0 {								// Flag an error if there is another comma (POSSIBLY SUBJECT TO CHANGE)		***
		local err = "Only one options list is allowed with up to 15 varlists{txt}" // See previous call on 'errmsg' for display options
*               	 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		errexit "`err'"										// 'errexit' w 'msg' as arg displays msg in results window and also in stopbox
		exit												// Exit returns execution to calling program (in stackMe the 'caller')
	}
	if strpos("`rest'","||")>0  {							// Flag an error if there are "||" after comma (POSSIBLY SUBJECT TO CHANGE)	***
		errexit "Pipes – || – not allowed after comma that terminates (last) varlist"
*				 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		exit												// errexit error string cannot exceed 80 chars
	}														// SEE COMMENTS FOLLOWING NEXT CALL ON 'errexit', in codeblk(1)
															
														 
	gettoken options postopt : rest, parse("||")			// Options string ends either with a "||" or with the end of cmd-line
															// (if there were "||" parsing chars, they were placed at start of `rest')
															// (if options end with "||" don't strip those pipes from start of 'postop')
          
	****************************************				// NOTE that `preopt' got its contents from prior 'gettoken preopt rest :'
	local multivarlst = "`preopt'`postopt'"					// Local that will hold (list of) varlist(s)
	****************************************				// (it doesn't matter where ", options" sat within `cmdstr'; this code
															//  leaves us with complete `multivarlst' and separate `options') 
															// (Note that pipes left at start of 'postopt' now terminate 'preopt')
	

	
	
	
	
	
	
global errloc "wrapper(0.2)"	
pause (0.2)




										//		 *********************************************************************************
										// (0.2) Codeblock to extract the `prefixtype' argument and `multiCntxt' flag that preceed 
										//		 the parsing `mask' (see any calling `cmd' for details); discovers the option-name 
										//		 of the first argument – an option that will hold any varname or list of varnames 
										//		 that might be supported by a stackMe command and might instead be supplied by a 
										//		 pre-colon prefixlist prepended to each varlist (varlist prefixes can be different 
										//		 for each varlist whereas options cannot).
										//		 *********************************************************************************		 
	
	
	if substr("`mask'",1,1)=="\"  { 						// Skip the backslash that delimits start of `mask'
	    local mask = strtrim(substr("`mask'",2,.))
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




										// (1) Process the options-list (follows the perhaps several varlists from codeblk 0.1)
										// 	   (some code supporting multiple optns lists is retained in case of a future revision)

										
	local keep = ""										// will hold 'opt1' from 0.2 plus contextvars, itemname, stackid, if optd
	
	local options = "`saveoptions'"						// Retrieve `options' saved in codeblk 0.1
	
	if substr("`options'",1,1)==","  {					// If `options' (still) starts with ", " ... APPARENTLY IT DOESNT				***
		local options = strltrim(substr("`opts'",2,.))	// Trim off leading ",  " 
	}						
														// This code permits successive optlists to update active options
														// (experimantal code now redundant but retained pending future evolution)
														
	if "`options'"!=""  {								// If this varlist has any options appended ...							
	 
		local opts = "`options'"						// Cannot use `options' local as that gets overwritten by syntax cmd)
		
		gettoken opt rest : opts, parse("(")			// Extract optname preceeding 1st open paren, else whole of word
														// NOTE: 'opt' and 'opts' are different locals

/*														// duprefix WAS NOT IMPLEMENTED IN LATEST VERSION OF GENDUMMIES?				***				
		if "`cmd'"=="gendummies" &"`opt'"=="prefix" { 	// (any unrecognized options might be legacy option-names)
			display as error "'prefix' option is is named 'duprefix' in version 2. Exiting `cmd'." 
			window stopbox stop "Prefix option is named 'duprefix' in version 2. Exiting command."	
		}												// (also, `opt' is named `opt1', saved at end of codeblk 0.2)
*/		if "`cmd'"=="gendist"  {
		   if "`respondent'"!=""   {
		      errexit "Option 'respondent' is option 'selfplace' in version 2" // 'msg' as argument is both displayed and windowed
			  exit										// ('msg' as option is windowed but needs 'display' option to be displayed)
		   }											// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
		}
		
		

														// ('ifin' expressions may be appended to any or all varlists
		local 0 = ",`opts' "  							// Named opts on following syntax cmd are common to all stackMe commands 		
														// (they supplement `mask' in `0' where syntax cmd expects to find them)
														// Initial `mask' (coded in the wrapper's calling `cmd' was pre-processed
														//  in codeblock 0.2 above); options added here apply to all stackMe commnds
*		***************									// (except that genstacks cannot have NOCONtexts or NOSTAcks)
		global mask = "`mask'  NODiag EXTradiag CONtextvars(varlist) NOCONtextvars NOSTAcks prfxtyp(string) SPDtst"
														// Need a copy of full mask, established as below, for subprogram syntax stmt
		syntax , [ $mask * ] 						  	// (`mask' was establishd in caller `cmd' and preprocessd in codeblk 0.2)
*	    ***************	  								// (option SPDtst uses supposedly slower but simpler append file code)
														// (final asterisk in 'syntax' places unmatched options in `options')
						
		if "`options'"!=""  {							// Here check for user option(s) that don't match any listed above

/*														// COMMENTED OUT 'COS CHECK SHOULD BE IN 'genstacks', NOT HERE					***
		   if "cmd'"!="genstacks"  {					// Except for command 'genstacks', for which ...		   
			  local tail = "`options'"
			  foreach opt  in  nostacks  {				// 'nostacks' (perhaps more – hence 'foreach') is optional for all but genstacks
				 gettoken head tail : tail, parse("(")	// Put each options string in turn, up to the first/next "(", into 'head"
				 if substr("`head'",1,5)=="`opt'"  {	// If 'head' is "(nocon'" (minimum version of "(nocontexts)")
					local tail = substr("`tail'",1,strpos(")"))				  // `tail' has whatever else the user typed, up to ")"
					local options = subinstr("`options'","`head'`tail'","",1) // Substitute "" for options-string "`head'`tail'", once
				 } //endif
			  } //next `opt', if any					// (any additional exceptional `opt's would be added to 'foreach's "nosta")
			  
		   } //endif `genstacks'
		   
		   if "`options'"!=""  {						// If, after removing the above 'options'-string still has any options remaining
*/			  display as error "Option(s) invalid for this cmd: `options'"
			  errexit, msg("Option(s) invalid for this cmd: `options'")
														// Call on 'errexit' with optioned msg suppresses display, done just above
			  exit										// 'exit' cmd returns to caller, skipping rest of wrapper incldng skipcapture
*		   }
		}


		local lstwd = word("`opts'", wordcount("`opts'"))	// Extract last word of `opts', placed there in 0.2 & parsed above
		
		**************************
		local optionsP = subinword("`opts'","`lstwd'","",1)	// Save 'opts' minus its last word (the added 'prfxtyp' option)
*		**************************							// (put in 'optionsP' at end of codeblk 1.1 for use solely in wrapper)

															//**********************************************************************
		local optionsP ="`optionsP' limitdiag(`limitdiag')" // Append `limitdiag', which got lost somewhere
															// (perhaps indication that other options might also have been lost too)	***
*		if "`cmd'"=="genyhats" & "`depvarname'"=="" {		//**********************************************************************
*		   gettoken first rest : multivarlst, parse(":")	// COMMENTED OUT `COS NO LONGER PUTTING PREFIXED VAR INTO 'depvarname'
*		   if "`rest'"!="" local optionsP = "`optionsP' depvarname(`first')"
*		}													// Also `depvarname' if replaced by a prefix variable
															// (avoids having to require a `depvarname' to be optioned even if unused)
															// TOO CLEVER BY HALF!! NOW HOLDS FALLBACK NAME SHOULD LATER VARLIST NOT
															
															// Pre-process 'limititdiag' option
		if `limitdiag'== -1 local limitdiag = .				// Make that a very big number if user does not invoke this option
		if "`nodiag'"!=""  local limitdiag = 0				// One of the options added to `mask', above, 'cos presint for all cmds
		if ("`extradiag'"!="" & "`limitdiag'"=="0") local limitdiag = .

		local xtra = 0
		if "`extradiag'"!=""  local xtra = 1				// Flag determines whether additional diagnostics will be provided
		
		if "`stackid'"==""  {								// If there is no SMstkid, the data are not stacked
			if "`cmd'"=="genplace" {
				errexit "Command genplace requires stacked data"
				exit										// Return execution to caller, skipping rest of wrapper 
			}												// (inclding 'local skipcapture = ', the last flag in wrapper)
		}

		local stackid = "`SMstkid'"							// Local 'stackid' cannot be optioned in v2, so is used within wrapr
															// (as it was in version 1, for many flagging purposes)
		if ("`nostacks'" != "")  local stackid = "" 		// But treating stacked data as unstacked is still possible					***
															// (except in genstacks, where it is treated as an error – see 'cmd'O)
														
		if "`stackid'"!=""  {								// Else have SMstkid
		
			capture confirm variable S2stkid				// So check if also have S2stkid
			if _rc==0  {
				local dblystkd = "dblystkd"
				if `limitdiag' noisily display "NOTE: This dataset appears to be double-stacked (has S2stkid variable){txt}"
*						 		                1234567890123456789012345678901234567890123456789012345678901234567890123
			}
			else  {											// Stacked but not doubly-stacked
			    if `limitdiag' noisily display "NOTE: This dataset appears to be stacked (has SMstkid variable){txt}"				
			}
			
		} //endif 'stackid'									// SMstkid and other such will be put in working data 
															// (after 'origdta' has been saved)
		
		
		if "`cmd'"=="gendist"  {
		   if "`missing'"!=""  {
			  if strpos("mis all dif di2", substr("`missing'",1,3)) | ("`missing'"=="dif2"|"`missing'"=="diff2")  {
				 if "`missing'"=="di2" | "`missing'"=="diff2"  local missing = "dif2"	
			  }
		   }												// (so any of the above are treated as ok by program gendistP)
		   if "`missing'"=="mea"  local missing = "mean"	// In case users think just three chars will do (as with option-names)
		   if "`missing'"=="dif"  local missing = "diff"	// (corrections enable program gendistP to fast-process these options)
		} //endif "`cmd'"=="gendist"
		

		if "`cmd'"=="genyhats"  {
		   if "`adjust'"!=""  {								// If 'adjust' was optioned
			  local adjust = substr("`adjust'",1,3)			// Require only 1st 3 chars of what user optioned for adjust
		   }
		   else  local adjust = "mea"						// If 'adjust' was not optioned, default is "mean"
		
		   if ("`adjust'" != "mea" & "`adjust'" != "con" & "`adjust'" != "no") {
			  display as error "Valid adjustment options are {opt mea:n}, {opt con:stant} or {bf:no}{txt}"
			  errexit, msg("Valid adjustment options are mean, constant or no")	
			  exit
		   }

		} //endif "`cmd'"=="genyhats"
		
		
															// *************************************************************
		global multivariate = "`multivariate'"				// GLOBAL RETAINS WHAT WAS OPTIONED; LOCAL IS `varlist'-SPECIFIC
		scalar MULTIVARIATE = "$multivariate"				// *************************************************************
															// (corresponding numbered scalar holds local version)
															// (see wrapper(2.1) for varlist-specific version)

				
														
	
		
		
		
	
global errloc "wrapper(1.1)"		
pause (1.1)


										// (1.1) Deal with 'contextvars' option/characteristic and others that add to the 
										//		 variables that need to be kept in the active data subset
										
										
	    local initerr = ""								// local will flag lack of established contextvars
	    local optadd = ""								// local will hold names of optioned contextvars to add to keepvars

		local usercontxts = "`contextvars'"				// To avoid being confused with contextvars from data characteristic
														// (use wordy 'usercontxts' for optioned contextvars, empty if none)
*		**********************							// Implementing a 'contextvars' option involves getting charactrstic
		local contexts :  char _dta[contextvars]		// Retrieve contextvars established by SMsetcontexts or prior 'cmd'
*		**********************							// (not to be confused with 'contextvars' user option)

		global contextvars = "`contexts'"				// This global is used by 'genstacks' and perhaps other stackMe commands
		
		if `limitdiag'  {								// Much of what is done here involves displaying diagnostics, if optioned
		  noisily display "{txt} "						// Insert a blank line if diagnostics are to be displayed
		
		  if "`contexts'"!=""  { 						// Characteristic shows existing contextvars
														// 'else' will be codeblk for no established contexts
			if "`contexts'"=="nocontexts"  {			// Contexts were defined as absent by SMsetcontexts
			  noisily display ///
			"{txt}NOTE: stackMe utility {help stackme##SMsetcontexts:SMsetcontexts} defined this dataset as having no contexts{txt}"
*		         12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  local contexts = ""						// So we don't take "nocontexts" to be a variable name!
			}              								// Will be displayed after end of 'limitdiags' codeblock

*			*******************************				// Cmd 'unab' balks at some varlists w both hyphenated and abbreviated vars 
			checkvars "`contexts' noexit"				// Unab the vars in 'contexts', also dealing with hyphenated varlists
														// Checkvars reports errors directly to 'errexit' unless 'noexit' is argued
			if "$SMreport"!=""  exit 					// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
*			*******************************				// $SMreport is only set by errexit, so this tells us there was an error

			local errlst = r(errlst)					// Returned by 'checkvars' (checkvars also returns r(checked))
			if "`errlst'"=="."  local errlst = ""		// SEEMINGLY r(errlst) RETURNS "." RATHER THAN ""								***
			if "`errlst'"!=""  {						// If there are any such...
				dispLine "This file's charactrstic names contextvar(s) not in dataset: `errlst'{txt}" "aserr"
				display as error ///								   
		        "Use utility command {help stackme##SMsetcontexts:SMsetcontexts} to establish correct contextvars{txt}"
*		                 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				errexit, msg("This file's contextvars charactrstic names variable(s) that don't exist: `errlst'")
				exit 									// (if errext msg is an option not an argument 'errext' does not display it)
			} //endif

		    else  {										// Else data characteristic holds valid contextvars
				noisily display "Established contextvar(s): `contexts'{txt}" 
				local gotcntxts = "yes"
			}
			 		  
			if "`usercontxts'"!=""  {					// If contextvars were user-optioned
			  if "`cmd'"=="genstacks"  {
			  	if "`gotcntxts'"==""  {					// If don't already have established contextvars..
			  	  errexit "Contextvars should have been established before invoking command 'genstacks'"
*		         		   1234567890123456789012 3456789012345678901234567890123456789012345678901234567890
				  exit									// 'exit' cmd returns to caller, skippng rest of wrappr incldng skipcapture
				}
			  }
			  
			  local same : list contexts === usercontxts
			  if `same'  noisily display ///			// Returns 1 if two strings match (even if ordered differently)
				 "NOTE: redundent 'contextvars' option duplicates established contexts{txt}"
				 
			  else  { 									// Else strings don't match
			     if "`cmd'"=="genstacks"  {
				 	if "`gotcntxts'"!=""  {
					   local txt = "Contextvars option contradicts established contexts"
					   noisily display "`txt'; ignore optioned choice:?'"
*		          					    1234567890123456789012 3456789012345678901234567890123456789012345678901234567890
					   capture window stopbox rusure "`txt' (`contexts'); ignore optioned choice of `usercontxts'?"
					   if _rc  {
					   	  errexit "Lacking permission to ignore optioned contexts"
						  exit							// Non-zero return code tels us user did not click 'OK'
					   }
					} //endif `gotcntxts'
				 } //endif `cmd'=="genstacks"
				 
				 else  {								// Else cmd is not genstacks
					noisily display ///
					"Optioned contextvar(s) temporarily replace(s) established data characteristic" 
*		          	12345678901234567890123456789012345678901234567890123456789012345678901234567890
					local contexts = "`usercontxts'"
				 }

			   } //endelse 'sme'
			
			} //endif `usercontexts'
		  
			
		  } //endif `contexts'
		  		  
		  else  {										// Else _dta[contextvars] characteristic was empty
		  
			 local initerr =  /// 						//  Non-empty 'initerr' gets this msg displayed after limitdiag ends
			 "stackMe utility {help stackme##SMsetcontexts:SMsetcontexts} hasn't initialized this dataset for stackMe"
*		                     12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   } //endelse

		  
		} //endif 'limitdiag'							// Next check involves an actual error that terminates execution
														// (Following if-block must be outside "if 'limitdiag'" braces)
		
		if "`initerr'"!=""  {							// If a msg was placed in local 'initerr', 3 lines up ...
			
		  display as error "`initerr'"					// This is the 'not initialized for stackme' error message above

		  if "`usercontxts'"!=""  {						// If there are user-optioned contextvars

		    local txt = "Instead, establish optioned `usercontxts' as this file's data characteristic?"
			display as error "`txt'{txt}"
			capture window stopbox rusure "`txt'"		// Putting the string into `txt' ensures `usercontxts' already decoded
			if _rc  {									// If user does not agree to this ...
			  display as error "Use stackMe utility {help stackme##SMsetcontexts:SMsetcontexts} to initialize this dataset{txt}"
*		                        12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  errexit, msg("Use stackMe utility SMsetcontexts to initialize this dataset)" // Comma stops msg being 'display'd
			  exit										// 'exit' returns to caller, skipping rest of wrapper incldng skipcapture
			} //endif _rc

			else {										// Else user is OK with defining data characteristic & continuing execution
			  char define _dta[contextvars] `usercontxts' 
			  noisily display "contextvars characteristic now established as `usercontxts'"
			}
			  
														// NOW WE HAVE TO REMOVE THAT 'contextvars' OPTION FROM 'optionsP'
			local l1 = strpos("`optionsP'", "con")		// (because we don't want any legacy coded 'cmdP' to find it there)			  
			if `l1'==0  errexit "contextvars error"		// Find start of 'contextvars' option, which may have been abbreviated
														// (cannot count on absence of those letters somewhere in another option)
			local tail = substr("`optionsP'",`l1', .'	// Put the (abbreviated) name, if any, plus remains of command into 'tail'
			local optP = ""								// Local will hold the option (perhaps abbreviated) as typed by the user
			while strpos("`tail'","con")>0  {			// While 'tail' has minimum optname and full match not found (see below)..
			  gettoken head tail : tail, parse("(")		// Treat what user actually typed as a token delimited by next "(" 
			  if substr("`contextvars'",1,strlen("`head'"))=="`head'" { // If exact match found with same-lengthed option-name..
			    local l2 = strlen("`tail'", ")" )		// Matched option ends at location of ")" in 'tail' ['tail' starts w "(" ]
				local optP = "`head'" + substr("`tail'",1,`l2') // Option as typed starts with head & ends at loc 'l2' in 'tail'
				continue, break 						// If there is a match w string of same lenth, break out of 'while' loop
			  }											// Else continue with next while loop
		    } //next 'while'							// (contextvars are now processed in wrapper, not in `cmd'P)
			
			if "`optP'"!=""  {							// ABOVE CODEBLK ENABLES US TO REMOVE 'contextvars' OPTION FROM 'optionsP'
			  local optionsP = subinstr("`optionsP'", "`optP'"," ",1) // Substitute " " for what was actually typed (incl space)
			}											// (assuming Stata has ensured it is there to be found)	  
			
		  } //endif 'usercontxts'
		   
		  else  {										// Else usercontxts were not optioned for this command
		   
			noisily display "Use stackMe utility {help stackme##SMsetcontexts:SMsetcontexts} to initialize this dataset{txt}"
*		                     12345678901234567890123456789012345678901234567890123456789012345678901234567890
			errexit, msg("Use stackMe utility SMsetcontexts to initialize this dataset") // Comma stops disply of 'msg' in reslts
			exit										// 'exit' cmd returns to caller, skipping rest of wrappr incldng skpcapture
			  
		  } //endelse

		} //endif 'initerr'
										
*		if `limitdiag'  display "Execution continues..." //DK IF NEEDED																	***
		   
		
		local contextvars="`contexts' " 				// Change of name fits with usage elsewhere in stackMe
														// (added space at end of local averts error when kept vars are cumulated)
														  


			
	
global errloc "wrapper(1.2)"
pause (1.2)

										// (1.2) Deal with first option, which holds an indicator variable name if `'prefixtype is 
										//		 "var" (see 0.2), else a string (depending on 'cmd'); also deals with references to 
										//		 SMitemand `itemname'
														
		
		local optad1 = ""								// Will hold indicator or cweight options
	
		local opterr = ""								// Reset opterr 'cos already dealt with previous set of error varnames

														// In the general case 'opt1' has name if first option in 'optMask' (0.2)
		if "`cmd'"=="genplace"  {						// But if this is as a 'genplace' command varlst could have 1 of 2 names
		   local opt1 = "indicator"
		   if "`wtprefixvars'"!=""  {					// If `wtprefixvars' was optioned...
		   	  local opt1 = "cweight"					// Have 'opt1' contain' the name of that var
		   }											// So, just as tho it had been first in the optMask
		}
		
		if "``opt1''"!="" & "`prfxtyp'"=="var"  {		// (was not derived from above syntax cmd but from end of codeblk 0.2)
		   local temp = "``opt1''"						// If 'cmd' is 'genplace', `opt1' will be `cweight' or 'indicator'
		   foreach var  of  local temp  {				// Local temp gets varname/varlist pointed to by "``opt1'"
			  capture confirm variable `var'			// See if any these vars exist
			  if _rc local opterr = "`opterr' `var'"	// Extend 'opterr' if not
			  else local optad1 = "`optad1' `var'"		// Extend 'optad1' otherwise
		   }					
	    }
		
		
	    if "`opterr'"!=""  {							 // Here issue generic error msg if above codeblk found any naming errors
			dispLine "Invalid optioned varname(s): `opterr'" "aserr"
		    errexit, msg("Invalid optioned varname(s): `opterr'")
			exit										// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
	    }
		  
		
		if "`itemname'"!=""  {							// User has optioned an SMitem-linked variable
		   capture confirm variable `itemname'
		   if _rc  {
		      errexit "Optioned 'itemname' is not an existing variable"
			  exit 										// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
		   }											// If 'itemname' survives this check it will be added to 'keepoptvars'		   
		}
		
	
	    if "``opt1''"!="" & "`prfxtyp'"=="var" {		// If first option names a variable(list)
		
*	  	  *****************************					// See first call on 'checkvars', in wrapper(1.1) above, for why it is invoked
		  checkvars "``opt1''"							// Double quotes get us to the varname(s) actually optioned
		  if "$SMreport"!="" exit 						// ($SMreport is empty if return code of 0 was reported)
*	  	  *****************************					// 'exit' cmd returns to caller, skipping rest of wrappr, incldng skipcapture
		  local checked = r(checked)

		  foreach var  of  local checked  {				// opt1 might be a varlist
		      capture confirm variable `var'			// Here get list of unconfirmed varnames
		      if _rc  local opterr = "`opterr' `var'"	// (in 'opterr)
		      else local optadd = "`optadd' `var'"		// Else add var to list of those in 'opt1'
		  } //next 'var'
		   
		  if "`opterr'"!=""  {
			  dispLine "Variable(s) in 'opt1' not found: `opterr'"  "aserr"
			  errexit, msg("Variable(s) in 'opt1' not found – see displayed list)"
			  exit										// Comma stops msg being displayed on output
		  }												// 'exit' cmd returns to caller, skipping rest of wrappr, incldng skipcapture
		 
		} //endif 'opt1'
	

	
															
		local keepoptvars = strtrim(stritrim("`contextvars' " + /// Trim extra spaces from before, after and between names to be kept
			  "`optadd' `optad1' `itemname'"))  			  	// Put all these option-related variables into keepoptvars. SMstkid,
																//   and other stacking identifiers will be handled separately
																// (`itemname' can be referenced only by using this alias)
																// (NOT SURE WHAT BENEFIT USER GETS FROM REFERRING TO IT INDIRECTLY)	***	
	  } //endif 'options'
	
	
	
	

global errloc "wrapper(2)"	
pause (2)								//		************************************************************************************
										// (2)  This codeblock extracts each varlist in turn from the pipe-delimited multivarlst
										//		established at the end of codeblk (0.1) and, after sorting the variables
										//		into input and outcome lists, pre-processes if/in/weight expressns for each varlist,
										//		then re-assembles those varlsts, shorn of 'ifinwt' expressns, into a new multivarlst
										//		that can be passed to whatever 'cmnd'P is currently being processed.
										//		************************************************************************************
	
																// Here we process multivarlsts for all cmds (including genstacks)
	   local multivarlst = strtrim(stritrim("`multivarlst'"))	// (ensure just one space between each component of 'multivarlst')	
	   local varlists = "`multivarlst'"							// Needed for 'while' command following 'if "`cmd'"=="genstacks"' below
	   global genstkvars = "`multivarlst'"						// Cluge helps to deal with genstacks having two varlist formats
	   local multivarlst = ""									// ('multivarlst' is reconstructed towards end of this codeblk)
	   local lastvarlst = 0										// Will be reset =1 when final varlist is identified as such
	   local outcomes = ""										// Varnames that will provide string-prfxed outcome varnames (see 2.1)
	   local inputs = ""										// Only for 'genyhats' does one of these morph into an outcome varname
																// (otherwise, 'inputs' will hold names of supplementary input vars)
	   local prfxvars = ""										// Varnames that appear as prefix to varlist (prfxvars end w colon)
	   local strprfx = ""										// Prefix string (max 1 per varlst) can help distngush between varlsts
	   local keepwtv = ""										// Up to 2 (hopefully identified) weight vars to be kept in (2.2)	
	   local errlst = ""										// List of supposed varnames found not to exist
	   local opterr = ""										// Used repeatedly to collect list of erronious options/varnames
	   local ifvar = ""											// Optionally filled later in this codeblk: var associated w 'if' exp
	   local wtexplst = ""										// Optionally filled later in this codeblk: the weight expression
	   local noweight = "noweight"								// Flag indicates no weight expression as yet for any varlist
	   local nvarlst = 0										// Count of varlsts in the multivarlst (default =0, flaggng an error)
																// (updates $nvarlst as it is itself updated – SUBJECT TO CHANGE)		***
																
	  
	   *******************************************************************************************************************************
	   *																															 *
	   *	   multivarlst -> varlists -> anything -> inputs&outcomes ->  ->  ->  ->  ->  ->  ->  ->  -> keepvarlsts -> keepvars	 *
	   *	   											   gotSMvars -^  cweight & indicator & prefix -^   ifvar&keepwtv -^  		 *
	   *	  																   optadd & optad1 ^	     contextvars ^				 *
	   *																															 *
	   *	[Schematic of route (approx ordered by position in wrapper) to identifying vars that need to be kept in working data]	 *
	   *																															 *
	   *******************************************************************************************************************************																	
		
		
				  

	
*	   **************************									******************************************************************
	   if "`cmd'"!="genstacks"  {									// FOR GENSTACKS, FOLLOWING CODEBLKS ARE SUBSTITUTED IN genstacks0
*	   **************************									******************************************************************

*		 **************************  								// `varlists' was initialized above from 'multivarlsts'
		 while "`varlists'"!= ""  {									// Repeat while another pipe-delimited varlist remains in 'varlists'
*		 **************************									// (so rest of codeblk is collecting lists of items, 1 per varlist)							
																	// Here parse the stackMe varlist, generally with following format:
																	// [[string_]inputvar(s):] outcomevars [ifin][weight] [no opts here]
																	// (strictly, all vars are inputs; some yield str-prefxed outcomes)

		   gettoken anything varlists : varlists, parse("||")		// Put successive varlists (delimited by "||") into 'anything'
		   if "`varlists'"==""  local lastvarlst = 1				// If more pipes don't follow this 'varlist', reset 'lastvarlst'=1 
		   else local varlists = strtrim(substr("`varlists'"),3,.)	// Else remove those pipes from what is now the head of 'varlists'
																	// (and trim off any following blanks)
																
		   local nvarlst = `nvarlst' + 1							// `nvarlst' from codeblk 0, line 58, counts n of varlists in cmd
																
		   local 0 = "`anything'"									// This is the varlist [if][in][weight], options typed by the user
																	// (placed in local `0' because that is what 'syntax' cmd expects)
																	
		   local saveanything = "`anything'"						// WHEN SYNTAX PROCESSES `anything' IT MANGLES & STOPS W PREFIXES
																	// (so will need to restore it (up to [ifinwt]) after processing)
		   ***************	
		   syntax anything [if][in][fw iw aw pw/]					// (trailing "/" ensures that weight 'exp' does not start with "=")
*	       ***************											// Syntax command finds in `anything' following 'ifinwt' & options
																	
						
		   if `nvarlst'==1  {										// If this is the first varlist
		   
			  local endv = ""										// By default assume no "if","in" or "weight" following the varlist
			  
			  local ifin = "`if' `in'"								// Ensure 'if' and 'in' expressions occur only on first varlist
		
			  if "`if'" != ""  {									// If not empty, calls for `if' when establishing a working dataset
				 local endv = "if"
				 tempvar ifvar										// Create a temporary variable to indicate which obs will be kept
				 gen `ifvar' = 0									// Don't know name(s) of vars in 'if' expression but can substitute 
				 qui replace `ifvar' = 1 `if'						//  this indicator whose name is known
				 local ifexp = "if `ifvar'"							// Local will be empty if none. NOTE there is only one ifexp per cmd
			  } //endif `if'										// THINK ABOUT TREATING IFVAR AS A ./1 VARIABLE FOR EACH VARLIST	***
		
			  if "`in'"!=""  {										// If not empty, calls for `in' when establishng the working dataset
				 if "`endv'"=="" local endv = "in"
				 local inexp = "`in'" 								// Store in inexp
			  } //endif `in'										// If "'inexp`nvl'"!="" code "`inexp`nvl'" in codeblock 6 below

																	// Weight expressions will be evaluated varlist by varlist
		   } //endif 'nvarlst'==1									// What follows applies to ALL varlists
		   
		   if "`endv'"=="" & "`weight'"!=""  local endv = "[w"		// If no [ifin] still may be `weight'
		   
		   
*		   ******************************************************	// HERE REMOVE ALL FROM `endv' TO END OF `saveanything' (SEE ABOVE)
		   if "`endv'"!=""  gettoken anything rest : saveanything, parse("`endv'") // 'rest' now has any 'ifin'|[wt; anythng has neithr
*		   ******************************************************	// Else no need to strip anything from end of varlist
		   else local anything = "`saveanything'"					// (we will restore this varlist after we finish weight processng)
																	// (at "local multivarlst "..., below)
		   
		   if `nvarlst'>1  {										// Later varlsts should not be found with 'genme' or have ifin expressions
		   
		      if "`cmd'"=="genmeanstats"  {
			  	 errexit "genmeanstats should not have more than a single varlist"
				 exit
			  }
		   
		      local ifin = "`if' `in'"
		   	  if "`ifin'"!=""  {
		   		  errexit "Only 'weight' expressions are allowed on varlists beyond the first; not if or in"
*               		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  exit												// 'exit' command takes us back to caller, skipping rest of wrappr
				  
			  } //endif
			  
		   } //endif `nvarlst'>1									// 'anything' now contains just varlists or a stublist
		   
		   
		   if "`weight'"!=""  {										// If a weight expression was appended to the current varlist
																	// (the trailing "/" in the weight syntax eliminates redundnt blank)
			  local wtexp = subinstr("[`weight'=`exp']"," ","$",.)	// Substitute $ for space throughout weight expression
																	// (ensures one word per weight expression)
																	// (has to be reversed for each varlist processed in 'cmd'P)
																	
		 	  ***************										
			  getwtvars `wtexp'										// Invoke subprogram 'getwtvars' below, maybe calling errexit
			  if "$SMreport"!=""  exit								// Skip rest of wrapper, including 'skipcapture' thru' exit to callr
*		 	  ***************										// $SMreport is empty if getwtvars did not call 'errexit'
	   
			  local wtvars = r(wtvars)
			  if "`wtvars'"=="."  local wtvars = ""					// SEEMINGLY r(wtvars) RETURNS "." WHEN wtvars IS EMPTY				***
			  local keepwtv = "`keepwtv' " + "`wtvars'"				// Append to keepwtv the 1 or 2 vars extracted by prog 'getwtvars'
																	// (use double-quotes to access the var(s) pointed to by `wtvars')
			  local noweight = ""									// Turn off 'noweight' flag; calls for full tracking across varlsts
																	// (should match what 'syntax' WOULD have delivered if no prefixes)
																	
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
		   
*		   ***************************************		  			// (CONCEPTUALLY, THIS PADDING OF 'wtexplst' BELONGS WITH 
		   global wtexplst`nvarlst' = "`wtexplst'"					//   $varlists`nvarlst', ETC., FILLED AT END CODEBLK(2.1); dealt
*		   ***************************************					// 	 with here 'cos there is one per varlist)
			
	

	
																

			
		
*pause on			

global errloc "wrapper(2.1)"
pause (2.1)


										//		 *******************************************************************************************
										// (2.1) Here check the validity of vars split into 'inputs' `prfxvars' and 'prfxstrs' for each varlst. 
										//		 All outcome variables will get names based on input varnames (except with gendummies, if stub-
										//		 names are optiond/listd that provide outcome varnames). Vars we here call 'prfxvars' are vars 
										//		 that provide additional data needed to generate desired outcomes, but without defining the 
										//		 outcome variable name (except for genyhats, where a prfxvar can provide an outcome name). As
										//		 well as supplementary variables, varlists can also provide string prefixes that exist only
										//		 to tweak the name of an outcome variable. Such a strprfx can update, for each varlist, the 
										//		 user-defined string prefixes that can be optioned for each command (useful, since there can 
										//		 only be one optionlist for each set of varlists that accompany a command). So when parsing 
										//		 a varlist we look for outcomes, input vars and input strings (we also ensure all vars are 
										//		 unabbreviated and that hyphenated varlists are expanded). NOTE that several outcome vars are
										//		 generally produced that share the same input varname, the outcome names being distinguished
										//		 by their different string prefixes. The number of prfxstrs that we collect determines the
										//		 number of different outcome variables that are generated by a single command, with names 
										//		 based on the same input varname. BEAR IN MIND that a prfxstr is a compound entity, produced 
										//		 by combining user-optioned strings with varlist prefix strings.
										//		   All this complexity should not trouble the average stackMe user, preparing a single-survey
										//		 dataset for a single country (perhaps even a time-series cross-section dataset with multiple
										//		 surveys from the same country) who can use the standard Stata << varlist [ifinwt], options >>
										//		 command format with a single varlist per command. The few who are pre-processing multiple
										//		 time-series cross-section data will hopefully be motivated to learn how to process several 
										//		 varlists on one single pass through these enormous datafiles.
										//		 ********************************************************************************************

			 local stub = ""										// Presence of a gendummies stub is used as a flag below
			 local postul = ""										// Ditto for `postul'
			 local gotat = ""										// Ditto for `gotat'
				
				
		     gettoken precolon postcolon : anything, parse(":")		// Parse components of 'anything' based on presence of ":", if any,
	
			 if "`postcolon'"==""  {								// If 'postcolon' is empty then there is no colon
				
			   local prfxvar = ""									// If there is no colon, store empty string for prfxvar, and prior
			   local strprfx = ""									// Empty by default (there can only be one strprfx per varlst)
*			   ************************								// Here we pre-process hyphenated and abbreviated un-prefxd varlist
			   checkvars "`anything'"								// Vars provde most inputs (with colon some pre-processng is needed)
			   if "$SMreport"!=""  exit								// Exit if 'checkvars' reported an error
*			   ************************								// See first call on 'checkvars', in wrapper(1.1) above. for details
			   local vars = r(checked)								// (get vars from r(checked), not 'anything', whch may have hyphens)
																	// (by default there r no inputs other than those becoming outcmes)
																	
		     } //endif 'postcolon'									
		   
		     else  {												// Else there IS a colon, so 'inputs' get (perhps tail of)`precolon'
		   
			   local vars = strtrim(substr("`postcolon'",2,.))		// 'vars' is tail of 'postcolon' after ":" is removed from its head 
			   
			   **********************								// Here we pre-process hyphenated and abbreviated pre-colon varlist
			   checkvars "`vars'"									
			   if "$SMreport"!="" exit								// Exit if 'checkvars' invoked 'errexit'
*			   **********************
			   local vars = r(checked)								
																	// (there will be one more var if there is a "yh@" flag)
			   gettoken preul gotat : precolon, parse("@")			// Look for "yh@" flag (signaling start of multvariate yhat varlist)
			   if "`gotat'"!=""  {									// If `gotat' not empty, strng strts wth "@" (need scalr flag below)
				 local postul = stritrim(substr("`gotat'",2,.))		// (anything that preceeds "@" is already in `preul'
			   }													// (trim any spaces inside `goat' – eg "yh@ TURNOUT")
			   
			   else  {												// Else there is no @ parsing char; still might be a "_" parsng char
			   	  gettoken preul postul : precolon, parse("_")		// "_" is treated exactly as "@" (but leaves no `gotat' indicator)																
			      if "`postul'"!=""  {								// If 'postul' not empty then there is a "_" parsing char
					 local postul =stritrim(substr("`postul'",2,.)) // Remove any spaces inside `postul' (e.g. following the "_")
				  }
			   } //endelse `gotat'  								// Next look for contents of `preul' (same whichever parse was used)
																	// With either parsing char, postul will contain what followed
			   if "`postul'"!=""  {									// (non-empty `postul' also tells us that `preul' is not empty)
			   	  local strprfx = "`preul'"
				  local prfxvar = "`postul'"						// With either parsing char, `postul' had that char removed above
				  if "`cmd'"=="gendummies"  local stub = "`postul'" // If command is 'gendummies' `postul' contains stubnames
			   }
			   
			   else  {												// Else `postul' is empty so there was neither string prefix
				  local strprfx = ""								// Make `strprfx' empty
				  local prfxvar = "`precolon'"						// All of `precolon' goes into `prfxvar' (whether 1 or more vars)
				  if "`cmd'"=="gendummies" local stub="`precolon'" 	// For gendummies, precolon would hold stubname(s)
			   }
			 
			   **********************								// See 1st call on 'checkvars', in wrappr(1.1) abve, for its purpose
			   checkvars "`prfxvar'"								// Pre-process hyphnatd & abbrevtd string prfxs to supplementry vars
			   if "$SMreport"!="" exit								// Exit if 'checkvars' invoked 'errexit'
*			   **********************
			   local prfxvar = r(checked)
																	// Now set flag and add variable occasioned by any `yh@' prefix
			   if "`gotat'"!=""  {									// 'genyhats' is only cmd for which a `prfxvar' would be an input
				  local multivariate = "yes"						// (global multivariate is not changed; flags an optned multivariate)
				  local dvar = "`prfxvar'"							// For genyhats precolon contains a (possibly prefixed) input var
			   } //endif `goat'										// (`gotat' both acts as ht@ flag and supplies `dvar' for `genyhats')
			   
			 } //endelse `postcolon'								// That should cover all possible varlist formats
*			 
			 
			 local input = "`vars'"									// By default, inputs provide the body for each outcome varname
																	// (`vars' come from one of the calls made on 'checkvars', above)

			 if "`cmd'"=="gendummies" {								// For gendummies, inputs come either from `vars' or from `stub'
			 
				local nvars = wordcount("`vars'")					// Find length of outcome varlist
				if "`stub'"!=""  {									// If a gendummies stub prefix was found above
				   local nstubs = wordcount("`stub'")				// (gendummies may have multiple stubnames)
				   if `nvars'!=`nstubs'  {							// If there are any stubs, ensure as many stubnames as variables
			   	      errexit "gendummies must have as many stubnames as varnames in each pipe-delimitd varlist"
																	// (not mentioned is that a single stub can have a strprfx)
*               		       12345678901234567890123456789012345678901234567890123456789012345678901234567890
		 			  exit											// Exit to caller after error is reported by errexit
				   } //endif `nvars'!=`nstubs'
				} //endif `stub'"!=""
				
			 } //endif 'cmd'=="gendummies	
			 
			 
			 
			 
			 global SMwarned = 0									// Flag prevents warning from being duplicated
			 if `limitdiag' & "`strprfx'"!="" & !$SMwarned {		// (this error can occur for any command that has an opt1 var(list))
				noisily display _newline "NOTE: Prefix to varname overrides, for that varname, any `opt1' option{txt}"
*               						  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				global SMwarned = 1									// 'opt1' is the first option in every stackMe cmd's option list
			 }														// (it is the option that will be replaced by any 'prfxvars')
		  
			if "`input'"!=""  local inputs = "`inputs' `input'"		// Cumulate the inputs that will ultimately become prefixed outcomes 
			if "`prfxvar'"!="" local prfxvars="`prfxvars' `prfxvar'" // Cumulate list of prfxvars over varlists
																	// Above plural locals r accessd in wrappr; scalars r used elsewhere

																	// GLOBLS DON'T RETAIN CONTNTS THRU preserve/'restore'/`merge CYCLES
*			**************************************					// Here is the first step in accellerating all 'cmd'P programs
			scalar NVARLSTS = `nvarlst'								// Puts in scalar # of current varlist; ultimately n of varlists
			scalar VARLISTS`nvarlst' = "`input'"					// Store in scalar where can be found by 'cmd'P and elsewhere
			scalar PRFXVARS`nvarlst' = "`prfxvar'"					// Store in scalar the name of var(list) that preceed a colon
			scalar PRFXSTRS`nvarlst' = "`strprfx'"					// String may prefix a prfxvar(list) – only one per prfxvar(list)
			scalar VARSTUBS`nvarlst' = "`stub'"						// (Lst of) stub(s) matchng N of vars in current varlst (only gendu)
			scalar MULTIVARIATE`nvarlst' = "`multivariate'"			// Successive genyh varlists may invoke multivariate analysis or not
			scalar GOTAT`nvarlst'	 = substr("`gotat'",2,.)		// EITHER ONE OF THIS OR ABOVE SCALAR MAY BE REDUNDANT
*			**************************************					// PARALLEL GLOBAL wtexplst`nvarlst' WAS FILLED IN CODEBLOCK (2)
																	
			local outcome = ""										// This string needs to be emptied for next varlist
			local input = ""										// Ditto
			local prfxvar = ""										// Ditto
			local strprfx = ""										// And ditto
							


		   local atloc = strpos("`anything'","@")					// SAVE A VERSION OF 'anything' (WITH ANY `yh@' REMOVED) BACK INTO `multivarlst'
		   if `atloc'  local anything = substr("`anything'",`atloc'+1,.) // Strip @ and any prior string-prefix from head of `anything'
		   
																	// (we want varlists to include hyphens if user typed those but don't want
																	//  any pre-@ prefixes to mess up 'syntax' commands in subprograms)
		   
*		   *************************************************		// (restored `anything was created at 'gettoken', after 'while varlists' above
		   local multivarlst = "`multivarlst' `anything' ||"		// Here multivarlst is reconstructed without any 'ifinwt' expressns
*		   *************************************************		// (any such were removed by Stata's syntax command; instead weights

		   if `lastvarlst'  continue, break							// If this was identified as the final list of vars or stubs,						
																	// ('break' ensures next line to execute follows "} //next while")
											
*	   	 ****************											********************************************************************
		 } //next `while'											// End of codeblks processing successive varlists within multivarlst
*	     ****************											// Local lists processed below cover all varlists in multivarlst	
*																	********************************************************************
											
	
		 local llen : list sizeof wtexplst							// Finish up the wtexplst now all varlists have been processed	
		 while `llen'<`nvarlst'  {	
			local wtexplst = "`wtexplst' null"						// Pad any terminal missing 'wtexplst's (must be after 'next while')
			local llen : list sizeof wtexplst
		 }
	
*	  	 ************************************
		 local keepifwt = "`ifvar' `keepwtv'"						// Must be appended after exiting 'while' loop `cos only done once 
*	  	 ************************************						// (list of vars/stubs will provide names of vars generatd by 'cmd'
																	//  per varlst WAS encoded in $wtexplst' in (2), updated just above)

		
																	
																	
*	 ********************											***********************************************************																	
	} //endif ! genstacks											// End of codeblockS executed for all cmds except genstacks	
*	 ********************											***********************************************************

																
	global limitdiag = `limitdiag'									// (first point at which this global can be set by all commands)
	
	
	if substr("`multivarlst'",-2,2)=="||" {							// See if last varlist ends with "||" (user might have done this)
		local multivarlst = strtrim(substr("`multivarlst'",1,strlen("`multivarlst'")-2)) 
	}																// Strip those pipes if so
																	

	global multivarlst = "`multivarlst'"							// Make it accessible to caller programs and subprograms
																	// (`multivarlst' has list of all varlists, includes ":" and "||")



				
				
*	*******************
	checkSM "`inputs'"												// Establish whether SMvars are referenced in user's varlist
	if "$SMreport"!=""  exit 										// Short-cut skips remainder of wrapper including 'skipcapture'
*	*******************												// (if 'errexit' was called from 'checkSM')

	local gotSMvars = r(gotSMvars)									// 'gotSMvars' is list of any SMvars in the active data
	local gotSMvars = subinstr("`gotSMvars'",".","",.) 				// Remove any missing variable symbols (should not be any)

																	// WE DEAL WITH THESE IN CODEBLK (5)

			
																		// ********************************************************
*	*********************************									// Update 'keepvars' with additions from this codeblock
	local keeplist = "`keepoptvars' `keepifwt' `inputs' `prfxvars' `gotSMvars'"	// Vars identified for working data now in keeplist
	local keepvars = strtrim(stritrim(subinstr("`keeplist'",".","",.)))	// Eliminate any "." in 'keepvarlsts' (seemingly from unab)
	local keepvars : list uniq keepvars									// Only retain one exemplar of each var in workng dta
*	*********************************									// ********************************************************
	

	
	noisily display ".." _continue
	global busydots = "yes"												// Flag indicates previous display ended with _continue



	
	
	

global errloc "wrapper(3)"	
pause (3)

pause off		
										// (3) Check various options specific to certain commands for correct syntax; add to
										//	   'keep' list any 'opt1' (and 'opt2 for genplace) – the first variable(s) in any 
										//		optionlist) – if those option(s) name variable(s).
										


	forvalues nvl = 1/`nvarlst'  {								// Cycle thru successive varlists
	   local prfxvars = PRFXVARS`nvl'							// Get prefixvars for that varlist
	   if "`prfxvars'"!=""  {
	   	  if strpos("gendummies geniimpute genplace", "`cmd'")==0 { // If `cmd' is not one of those listed ..
			 if wordcount("`prfxvars'")>1  {
			   	errexit "Only gendummies geniimpute and genplace can have multiple 'prefix' vars/stubs"
*               		 12345678901234567890123456789012345678901234567890123456789012345678901234567
			    exit											// Exit takes us straight to caller, skipping rest of wrapper
			 } //endif wordcount
			 
		  } //endif `cmd'
	   } //endif 'prfxvars'
	   else  {													// Else there is no prefixvar (genyhats can only have one)
	   	  if "`cmd'"=="genyhats" & "`depvarname'"=="" { 		// genyhats requires an optioned depvarname if no prefixvar
			 if "$multivariate"!=""  {
				errexit "For a multivariate analysis with no yh@ prefix, a depvarname must be optioned"
*               	  	 12345678901234567890123456789012345678901234567890123456789012345678901234567
			 }
			 else errexit "For a bivariate analysis (default), a depvarname must be optioned" 
		  } //endif `cmd'=="genyhats"
	   } //endelse
	} //next 'nvl'

	
	if "`cmd'"=="genplace" & "`indicator'"!=""  {				// `genplace' is the only cmd with additional var-naming optn 		***
																// (beyond the 'opt1' option handled above) so handle it here
	   gettoken ifwrd rest : indicator							// See if "if" keyword is first word in 'indicator'
	   if "`ifwrd'"=="if"  {									// If "`indicator'" string starts with "if"
		  if "`rest'"=="" {
			 errexit "Missing 'if' expression"
			 exit
		  }
		  tempvar indicator										// If indicator is created with 'ifind', make it a tempvar
		  qui generate `indicator' = 0							// So generate a new var named 'indicator', 0 by default
		  qui replace `indicator' = 1 if `rest'					// Replace values of that variable to accord with 'ifind' expression
	   }														// ('ifind' may include varname(s) but don't need to keep those)
	   else unab "`indicator'"									// Else 'indicator' contains a varname; unabbreviate it
																// ('unab' will exit with appropriate error msg if no such var)
	} //endif 'cmd'=='genplace'									// ('indicator' local now names either original or tempvar variable)
	
																// **************************************************************
	local keepvars =strtrim(stritrim("`keepvars' `indicator'")) // Update 'keepvars' with additions from this codeblock
																// ***************************************************************
							
						
	
	if "`cmd'"=="genmeanstats"  {							// 'genmeanstats' makes unique use of two-character outcome var prefixes
															// (user-selected by employing its 'stats' option)
		global statprfx = ""								// Three globals share this linkage with relevant subprograms
		global statrtrn = ""								//
		global statpos = ""									// Initialize global as head of list that will accumulate all `statpos's

		local 0 = ", `stats'"								// Local 0 is where `syntax' command expects to find user's command line
															// ('stats' is name of option in which user placed desired stats)
		syntax , [ N MEAn SD MIN MAX SKEwness KURtosis SUM SWEights MEDian MODe _all ] // List is also in 's0', differently formatted
															// Command 'syntax' selects those actually optioned, in 's1' below
		local s0 =     lower("N MEAn SD MIN MAX SKEwness KURtosis SUM SWEights MEDian MODe") // List of stats (r-names) in lower case
		local s1 = strtrim(stritrim("`n' `mean' `sd' `min' `max' `skewness' `kurtosis' `sum' `sweights' `median' `mode'")) // optiond stats
		local s2 = strtrim(stritrim( "n   me     sd   mi    ma    sk         ku         su    sw         md       mo"   )) // Prefix initls
															// Actual return names: "N" for "n"; "sum_w" for "sweights"	
		if "`_all'"!="" {									// if "_all" was optioned
		
		   if wordcount("`s1'")>0 {							// if any other stats were optioned
			  errexit "Cannot option any other stats along with '_all'"
			  exit											// Invoke errexit
		   }
		   local s1 = subinstr("`s0'"," _all","",1)			// Otherwise make like all stats (except "_all") were optioned
		}													// Rest of "while `count'" is same whether '_all' was optd or not
		
		local nstats : list sizeof s1						// N of optioned stats now in 's1' after 'syntax' cmd, above, was executed
		forvalues i = 1/`nstats'  {							// Cycle thru optioned 'stats'
			local stat = word("`s1'",`i')					// Put each one in turn into `stat'
			local j : list posof "`stat'" in s0				// Find position of that stat in 's0's list of stats that might be optioned
			global statpos = "$statpos `j'"					// Append result to global list of positns of r-names & prefxes in `s0',`s2'
			global statrtrn = "$statrtrn "+word("`s0'",`j')	// (of stats optioned in `s1')
			global statprfx = "$statprfx "+word("`s2'",`j')
		}													// (globals to be accessed in  'genstatsP' & 'cleanup' for pfxng and labelng)

	} //endif `genmeanstats'
		
	scalar STATRTRN = "$statrtrn"							// As with VARLSTS etc. these globals are not retaining their contents
	scalar STATPRFX = "$statprfx"							// (perhaps because they get emptied in the course of preserve/restore cycles)

	

	
	
	
global errloc "wrapper(4)"
pause (4)
										//	   ***********************************************************************************
										// (4) Save 'origdta'. This is the point beyond which any additional variables, apart from
										//	   outcome variables generated by stackMe commands, will not be included in the full 
										//	   dataset after exit from the command or after restoration of the data following an 
										//     error. Here initialize ID variables needed for stacking and to merge working data 
										//	   back into original data. Ensure all vars to be kept actually exist, check for any 
										//	   daccidental duplication of existing vars. Here we deal with all kept vars, from 
										//	   whatever varlist in the multivarlst set (except SMvars, added below if needed)
										//	   ***********************************************************************************
										   
																// ***************************************************************
	tempvar origunit											// Variable inserted into every stackMe dataset; (enables merge of
	gen `origunit' = _n											//   newly created vars back into original data in codeblk 9)
	local keepvars = "`keepvars' `origunit'"					// And added to keepvars
																// ***************************************************************
															
*	************
	tempfile origdta										// *******************************************************************
	quietly save `origdta', replace						    // Will be merged with processed data after last call on `cmd'P
	global origdta = "`origdta'"							// (, replace option in case file remained extant on prior error exit)
*	************											// Put it in a global so as to be accessible from anywhere
															// This is temporary file will be erased on exit 															// ('origdta' will be restored before exit in event of error exit)
															// *******************************************************************

			
*	***************											// ******************************************************************
	if "`ifexp'"!=""  keep if `ifvar'						// 'ifvar' is a 0-1 dummy encapsulating effect of any 'if' expression
*	***************											// NOTE: Any exit before this point is a type-2 exit not needing data 
															// 		to be restored. There should only be type-1 exits after this
															//		point (these DO require the full dataset to be restored)
															// (in subprogram errexit, $exit=0 is not distinguished from $exit=2)
*	***************											// ******************************************************************
	global exit = 1
*	***************
															// **************************************************************
	local temp = ""											// Name of file/frame with processed vars for first context
	local appendtemp = ""									// Names of files with processed vars for each successive context
															// **************************************************************

	
	
	
	
			
			
			
global errloc "wrapper(5)"			
pause (5)

										//	   *************************************************************************************
										// (5) Deal with possibility that prefixed outcome variables already exist, or will exist
										//	   when default prefixes are changed, per user option. This calls for two lists of
										//	   global variables: one with default prefix strings and one with prefix strings revised 
										//	   in light of user options. Actual renaming in light of user optns happns in final blks
										//	   or wrapper for each 'cmd' after processing by 'cmd'P; but users need to known before
										//	   'cmd'P is called whether there will be name conflicts. Meanwhile we must deal with any 
										//	   existing names that may conflct with outcome names, perhaps only after renaming.
										//	   *************************************************************************************
										
										
															
	if "`cmd'" != "genstacks"  {							// 'genstacks' command does not prefix its outcome variables
	
	  global exists = ""									// Empty list of vars w revised prefixes or otherwise exist as shouldnt	  

	  global prfxdvars = ""									// Global will hold the list of prefixed vars from subprogram 'isnewvar'.
	  global newprfxdvars = ""								// Ditto, for list of NOT already existing outcome vars 
	  global badvars = ""									// Ditto, vars w capitalized prefix, maybe due to previous error exit
	  

															// See if simulated names of outcome vars already exist
*	  ********************									// (identify dups and conflicts, helped by user input)
	  getprfxdvars , `optionsP' `multivariate'				// BUT WE DONT DROP THEM UNTIL WORKING DATA ARE MERGED WITH origdta
	  if "$SMreport"!=""  exit								// (`multivariate' reflects `gotat' prefix, not affecting $multivariate)
*	  ********************									// 'optionsP' holds options needed to identify optioned prefix-strings
															// $SMreport is copy of `errmsg' (indicator that we need to exit)

	} //endif 'cmd'!='genstacks
	

	
															// ******************************************************************
	if "$cmdSMvars"!=""  {									// (Global cmdSMvars filled by subprogram 'checkSM', invoked in 2.1)
															// HERE IS WHERE WE ADD COMMAND-SPECIFIC SMvars TO $exists SO USERS
															//  CAN DECIDE WHETHER TO DROP THEM
															// ******************************************************************
															
		foreach v  of  global cmdSMvars  {					// (cmdSMvars only exist for gendist geniimpute genstacks)		
		
			if "`cmd'"=="gendist" & strpos("SMdmisCount SMdmisPlugCount","`v'")>0  global exists = "$exists `v'"
			if "`cmd'"=="gendiimpute" & strpos("SMimisCount SMimisImpCount","`v'")>0  global exists = "$exists `v'"
			if "`cmd'"=="genstacks" &"`dblystkd'"=="" &strpos("SMstkid S2stkid SMnstks S2nstks SMitem S2item SMunit S2unit","`v'")>0 ///
				global exists = "$exists `v'"				// $exists already holds any conflicted varnames found by 'getprfxdvars'
			if "`cmd'"=="genstacks" & "`dblystkd'"!="" & strpos("S2stkid S2nstks S2item S2unit","`v'")>0 ///
				global exists = "$exists `v'"
															// (invoked in codeblock 5.0)
		} //next `v'
		
	} //endif $cmdSMvars
	
	
	
		
*pause on	
	
global errloc "wrapper(5.1)"
pause (5.1)


										//		 ****************************************************************************
										// (5.1) Call on '_mkcross' to enumerate all contexts identified by a single variable
										//		 that increases monotonically in increments of a single unit across contexts
										//		 (the final variable we need to include in the working dtaset)
										//		 Also check whether data has Stata missing data codes (>=.)
										//		 ****************************************************************************
		
	  checkvars "`contextvars'"								// Just in case these contain a hyphenated varlst – see 1st call in 1.1
	  if "$SMreport"!="" exit								// (don't seem to have made this check when parsing contextvars above)
	  local contextvars = r(checked)
	  
	  local nocntxt = 1										 
	  if "`contextvars'" != "" | "`stackid'" != ""  local nocntxt = 0  // Not nocntxt if either source yields multi-contxts
	  local nocntxt = 0										// Flag indicates whether there are multiple contexts or not
	  if "`cmd'"=="gendummies"  local nocntxt = 1			// gendummies treats whole dataset as one context
															// WE ALREADY HAVE A FLAG FOR THIS, SET IN CALLER						***

	  tempvar _ctx_temp										// Variable will hold constant 1 if there is only one context
	  tempvar _temp_ctx										// Variable that _mkcross will fill with values 1 to N of cntxts
	  capture label drop lname								// In case error in prev stackMe command left this trailing

	  if `nocntxt'  {
		gen `_temp_ctx' = 1									// Don't need _mkcross to tell us no contextvars = no contxts
	  } 
	  else {												// else we do have multiple contexts
	  
	    local cvars = ""
	    foreach var  of  local contextvars  {
		   clonevar c`var' = `var'
		   local cvars = "`cvars' c`var'"
		}
		local cvars = "`cvars' `stackid'"
			
		global contextvars = "`contextvars'"				// Somewhere, contextvars are getting replaced by their values
		local ctxvars = "`cvars'"							// So we insulate the originals and use clones until we save the data
															// (when we will use the global to retrieve then)


*		****************
		quietly _mkcross `ctxvars', generate(`_temp_ctx') missing strok labelname(lname)										 	//	***
		if "$SMreport"!=""  exit 							// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
*		****************									// 'SMreport' is only set by errexit, so this tells us there was an error
															// (generally calls for each stack within context - see above)
															// (enumerates only obs retained after 'ifexp' was executed in blk(4))


	  } // endelse 'nocntxt'
			
	  local ctxvar = `_temp_ctx'							// _mkcross produces sequential IDs for selected contexts
															// (NOT TO BE CONFUSED with `ctxvars' used as arg for _mkcross)
	  quietly sum `_temp_ctx'
	  local nc = r(max)										// This is the number of contexts (`c'), used below and in `cmd'P		
				
	
		

	
global errloc "wrapper(6)"													
pause (6)								//		 *****************************************************************************
										// (6)   Issue call on `cmd'O (for 'cmd'Open). In this version of stackmeWrapper the
										//		 call occurs only for commands listed; 'genyhats' will have opening codeblocks 
										//		 transferred to genyhtsO in a future release of stackMe. The programs called
										// 		 here are final sources of vars to be kept.
										// 		 Capture otherwise undiagnosed errors in programs called from wrapper
										//		 *****************************************************************************
										
										// *******************************************************************				 ***********
										// NOTE THAT IN THIS CODEBLK 'keepvars' TEMPORARILY MORPHS INTO 'keep' 	   (look for HERE MORPH)		
										// *******************************************************************				 ***********

										
										
	  
	  if "`cmd'"=="geniimpute" | "`cmd'"=="genplace" |"`cmd'"=="genstacks" {  // cmds having a 'cmd'O
	
															// Above 'cmd's all have a 'cmd'O program that accesses full dataset
															// (may add gendist & genyhats so only gendummies will be w'out 'cmd'O)
		if "`cmd'"=="genstacks"  local multivarlst = "$genstkvars"
															// Recover original multivarlst if call will be on genstacks
*	 	******************** 
		`cmd'O `multivarlst', `optionsP' nc(`nc') nvar(`nvarlst') wtexp(`wtexplst') ctx(`_temp_ctx') orig(`origdta') 
		if "$SMreport"!=""  exit 							// ($SMrc is empty if a non-zero return code was not reported)
*	 	********************								// (local c not included 'cos does not have a value at this point)
															// Global origdta IS included 'cos errors require origdta to be restored
															// Some 'cmd'O commands may still use legacy error reporting
		local temp = ""	
		if "`cmd'" == "genstacks"  {						// Command genstacks deals with own varlist/stublist
		
		   local temp = r(impliedvars)						// (other sources supply 'multivarlst' for other 'cmd's)
		   if "`temp'"=="."  local temp = ""
		   if "`temp'"!=""  global genstkvars = "`temp'"	// SEEMINGLY EMPTY										  ******************	***
		   local keep="`keepvars' `temp' `keepimpliedvars'"	// Append impliedvars to keepvars AND SAVE BOTH IN 'keep' HERE MORPH HAPPENS
		   local inputs = "`temp'"							//														  ******************
		   local multivarlst = r(reshapeStubs)				// Used in `cmd'P call, feeding 'reshapeStubs' to `cmd'P.
		   local multivarlst = subinstr("`multivarlst'",".","",.)   // Remove any missing variable symbols
		   local multivarlst = subinstr("`multivarlst'",":"," ",.)  // Remove any colons
		   local multivarlst = subinstr("`multivarlst'","||"," ",.) // Remove any pipes
		   local multivarlst = strtrim(stritrim("`multivarlst'"))	// Remove any superfluous spaces

		   local dups : list dups multivarlst				// Remove all ":" & "||"; trim all leading, trailing & internal extra blanks
		   if "`dups'"!=""  {								
			  local ndups = wordcount("`dups'")				// ******************************************************************
			  local duplen = strlen("`dups'")				// THIS CODEBLOCK copied from 'getprfxdvars' to do same for genstacks
			  local ndups = wordcount("`dups'") 			// ******************************************************************
			  
			  if `ndups'==1  {
				 capture window stopbox rusure "Duplicate outcome varname: `dups'; drop this var?"
			  }												// Will consult return code after 'else' clause
			  else  {										// Else if N of dups>1
				 local msg = "Duplicate outcome varnames: `dups'; drop these?"
				 dispLine "Duplicate outcome varnames: `dups'; drop these?" "aserr"
				 local rmsg = r(msg)
				 capture window stopbox rusure "`rmsg'"
			  } //enelse `ndups'
			  if _rc {
			  	 errexit "Lacking permission to drop duplicate varnames"
				 exit
			  }
			  
			  drop `dups'									// If no errorexit, drop all dups
			  
		   } //endif 'dups'									// END OF CODEBLK COPIED FROM `getprfxdvars'
		   
		   local outcomes = "$genstkvars"					// NAME IS ANOMOLOUS SINCE GENSTACK OUTCOMES ARE VARS THAT WERE STUBS
														    // (but wrapper does not know that)
		} //endif 'cmd'=='genstacks'
		
		  
		else  {												// Else for the other cmds currently having cmd'O programs
		  local temp = r(keepvars)
		  local temp = subinstr("`temp'",".","",.) 			// Remove any missing variable symbols							*******
		  local keep = "`keepvars' `temp'"					// And from `temp' to 'keep'							   		OR HERE		
		  local minmax = r(minmax)							// Only relevant to 'geniimpute' for now					    *******
		  if "`minmax'"=="."  local minmax = ""
		  if `limitdiag'  local fast = "fast"				// Only relevant to geniimpute; limits per context diagnostics
		}
					
			
	  } //endif 'cmd'== genii', 'genpl' 'genst'				// End of clause determining whether 'cmd'O was called
															// ('cmd'O may itself have flagged an error)														
	  else  {												// Else command is not one with special requarements for call on 'cmd'P
															//																*******
		local keep = "`keepvars'"							//																OR HERE
	  }														// 																*******
	
															// ********************************************************************
	  if "`SMstkid'"!=""  local keep = "`keep' SMstkid"		// And add 'SMstkid', if extant, for diagnostic displays
															// ********************************************************************														
															// (Last bit of 'keep' before dropping all other vars from working data)
	

	

	
	  if "`cmd'"!="genstacks"  {							// Get list of all outcomes for whatever command this may be
	  	local outcomes = ""									// (genstacks outcomes were already filled from r(impliedvars), abve)
	  	forvalues nvl = 1/`nvarlst'  {
	  	   local outcomes = "`outcomes' " + VARLISTS`nvl'	
		}
	  } //ndif
	  

	  
	  tempvar count											// Check whether Stata missing data codes are in use
	  local lastvar = word("`outcomes'",-1)					// Record this so can we tell when the last var has been tested
				
	  foreach var  of  local outcomes  {					// (similar code in 5.2 only if `showdiag'; & here overhead is small)

		egen `count' = count(`var'>=.)  					// Count any observations with values >= missing

		if `count' in 1  continue, break					// Break out of loop with first Stata missing data code found
		
		if "`var'"=="`lastvar'"  {							// If this was the final variable in 'outcomes'..
			local msg = "No variable in the working dataset has any Stata missing data codes"
*					 	 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			display as error "`msg'; continue?{txt}"
			capture window stopbox rusure "`msg'; click 'cancel' and recode your missing data – or 'ok' to continue anyway"
			if _rc  {										// If user did not click 'OK'
				errexit, msg("Recode missing data") displ	// Display msg in results window as well as stopbox
			}												// (we pass this point only if program did not exit)
		} //endif `var'
		
		noisily display "Execution continues..."
		
	  } //next var
			
	  drop `count'											// Drop this tempvar


	
*	  ***********************								// Check that all vars to be kept are actual vars
	  if "`keep'"!=""  {
		checkvars "`keep'"									// See 1st call on checkvars in wrapper(1.1) for purpose
		if "$SMreport"!="" exit 							// Exit takes us straight back to caller, skipping rest of wrapper
		local keep = r(checked)								// (May include SMitem or S2item generated just above)
	  }
*	  ***********************										
		
	  local keepvars : list uniq keep						// Stata-provided macro function to delete duplicate vars
															// (put in global so can be accessed by 'cmd' caller and subprograms)
															// (`keepimpliedvars' is a list of varnames BEFORE stacking)
	  global keepvars	= "`keepvars' `_temp_ctx'"			// ($keepvars' has all varlists and optioned vars with dups removed)
	
															// ***************************************************************
*	  **************										// HERE DROP UNWANTED VARIABLES FROM WORKING DATA FOR ALL CONTEXTS
	  keep $keepvars			 							// Keep only vars involved in generating desired results
*	  **************										// ***************************************************************



*										*************************************************************
										// NOTE THAT, JUST ABOVE, 'keep' MORPHED BACK INTO 'keepvars'
*										*************************************************************
	
					
global errloc "wrapper(6.1)"				
pause (6.1)								//		 ***********************************************************************************
										// (6.1) Cycle thru each context in turn 'keep'ing, first, the variables discovered above to
										//	     be needed in the working dataset and, later, the observations, selected by any 'if' 
										//	     or `in' expressions, before checking for context-specific errors.
										//		 ***********************************************************************************

	  if `nc'==1  local multiCntxt = ""						// If only 1 context after ifin, make like this was intended			
															// (seemingly unused)															***
	  if "`multiCntxt'"==""  local nc = 1					// If "`multiCntxt' is empty then there is only 1 context
															// ('multiCntxt' was initialized in `cmd'.ado)
																	  
														

*	  ********************									************************************
	  forvalues c = 1/`nc'  {								// Cycle thru successive contexts (`c')
*	  ********************									************************************



	
		local lbl : label lname `c'							// Get label associated by _mkcross with context `c' ('cmd'P 
															// programs can optionally have labelname 'lname' hardwired)
		scalar LBL = "`lbl'"								// (use a scalar so does not get dropped at exit from program)

															
*		********										 	**************************************************************
		preserve  								 		 	// Next 3 codeblks use only working subset of context `c' data
*		********										 	**************************************************************


*		************												//  THIS COMMAND KEEPS ONLY WORKING DATA FOR THE CURRENT CONTEXT
		quietly keep if `c'==`_temp_ctx' 							// `tempexp' starts either with 'if' or with 'ifexp &'
*		************									 			// ('ifexp' now executed after saving 'origdta' in blk 4)
				
   
*		******************************************		   		  
		if `limitdiag'>=`c' & "$cmd"!="geniimpute" /*& "$cmd"!="genstacks"*/ {																					 
*		******************************************		  			// Limit diagnostics to `limitdiag'>=`c' and ! (geniimpute|genstacks)	
		
*			******************************
			showdiag1 `limitdiag' `c' `nc' `nvarlst'
			if "$SMreport"!="" exit 								// ($SMrc is empty if a non-zero return code was not reported)
*			******************************							// Exit takes us straight back to caller, skipping rest of wrapper
			  
		} //endif `limitdiag'>=`c' & ...
			 				 
							 
	
	
	  	
	
global errloc "wrapper(6.2)"		
pause (6.2)


										// (6.2) HERE ENSURE WEIGHT EXPRESSIONS GIVE VALID RESULTS IN EACH CONTEXT OF WORKING DATASET	***
							
										
			forvalues nvl = 1/`nvarlst'  {							// Cycle thru all varlists for this command		 
	   				 
		       if "`wtexplst"!=""  {								// Now see if weight expression is not empty in this context

			     local wtexpw = word("`wtexplst'",`nvl')			// Obtain local name from list to address Stata naming problem
				 if "`wtexpw'"=="null"  local wtexpw = ""
				 
				 if "`wtexpw'"!=""  {								// If 'wtexp' is not empty (don't non-existant weight)
				   local wtexp = subinstr("`wtexpw'","$"," ",.)		// Replace all "$" with " "
																	// (put there so 'words' in the 'wtexp' wouldn't contain spaces)
				 
*				   ***************************							  
			       capture summarize `origunit' `wtexp', meanonly	// Weight the only var known to exist in a call on 'summarize'
*				   ***************************						// (known because we created it)

			       if _rc  {										// A non-zero error code is likely be due to the 'weight' expression

				   	local lbl = LBL									// Get a local copy of scalar LBL

				     if _rc==2000  errexit "Stata reports 'no obs' error; perhaps weight var is missing in context `lbl' ?"
				     else  {
					   local l = _rc
					   errexit "Stata reports program error `l' in context `lbl'" "`l'" // UPPER CASE lbl IS A SCALAR; `l' IS A RETURN CODE
				     }
					 exit											// Exit takes us straight back to caller, skipping rest of wrapper
																	
			       } //endif _rc

		         } //endif `wtexpw'
				 
			   } //endif `wtexplst'
			 
		    } //next 'nvl'
		   
		   
		   


	 	   
		  

global errloc "wrapper(7)"		
pause (7)


										//		*********************************************************************************
										// (7)  Issue call on `cmd'P with appropriate arguments; catch any `cmd'P errors; display 
										//		optioned context-specific diagnostics
										//		NOTE WE ARE STILL USING THE WORKING DATA FOR EACH IN TURN OF SPECIFIC CONTEXT `c'
										//		(IF NOT STILL SUBJECT TO AN EARLIER IF !$exit CONDITION)
										//		*********************************************************************************
	
set tracedepth 5	
																	
*		*******************				     	 					// Most `cmd'P programs must be aware of lname for ctxvars			***
		`cmd'P `multivarlst', `optionsP' nc(`nc') c(`c') nvarlst(`nvarlst') wtexplst(`wtexplst')
		if "$SMreport"!="" exit 									// ($SMrc is empty if a non-zero return code was not reported)
		*******************											// `nvarlst' counts the numbr of varlsts transmittd to cmdP
																	// Exit takes us straight back to caller, skipping rest of wrapper

			
			
		if "$cmd"!="geniimpute" {									// Limit diagnstics to commands other than 'geniimpute'		
																	// (geniimpute displays its own diagnostics)
		  if `limitdiag'>=`c'  {
		  	
*			*************************************	
			showdiag2 `limitdiag' `c' `nc' `xtra'					  
			if "$SMreport"!="" exit 							  	// ($SMreport is empty if an error was not yet reported)
*			*************************************

		  } //endif
		  
		  else  {													// If limitdiag IS in effect, print busy-dots
		  
			  if `limitdiag'<`c'  {									// Only if `c'>= number of contexts set by 'limitdiag'
				  if "`multiCntxt'"!= ""  {						// If there ARE multiple contexts (ie not gendummies)
					 if `nc'<38  noi display ".." _continue		// (more if # of contexts is less)
					 else  noisily display "." _continue			// Halve the N of busy-dots if would more than fill a line
				  }
			  } //endif
				
		  } //endelse
			
		} //endif ! geniimpute'
		
		
	  
	  
	  	
		local skipsave = 0										    // Will permit normal processing by remainder of wrapper 
																    // (unless overridden by next line of code)		
																	
																	// ***********************************************************
		if "`cmd'"=="genplace" & "`call'"=="" local skipsave = 1    // Skip saving outcomes if 'genplace' unless 'call' is optd
																	// If 'skipsave' was not turned on above..
																	// (Skip saving outcomes if 'genpl' was not optnd with 'call')
																	// (regular 'genplace' outcomes were generated in 'genplaceO')
		if  !`skipsave'  {											// ***********************************************************

	
	
	
*pause on	
global errloc "wrapper(8)"										    // This codeblock is only executed if 'skipsave' is not true
pause (8)				

								//		******************************************************************************************
								// (8)	Here we save each context in a tempfile for merging once all contexts have been processed.
								//		This means recording a filename for each context*stack in a list of filenames whose length
								//	is limited by the maximum length of a Stata macro (on my machine 645,200 bytes.) So the first
								//	time a dataset is processed we need to check on the max for that machine, find the length of
								//	the tempname (the string following the final / or \) and see if the product of contexts*stacks
								//	is less. If not we must start another list that will ultimately be appended to previous lists.
								//  All of this is mind-bogglingly complicated so first we try a simpler strategy to speed-test it
								//  NOTE THAT WE ARE STILL USING THE WORKING DATA FOR A SPECIFIC CONTEXT `c'
								//	**********************************************************************************************

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
//MOVED HERE FROM BELOW (LINE COMMENTED OUT), DEC'25				// (used to find total length needed for all prev files + this one)
			local namloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Posn of first char following final "/" or "\" of directory path
			
			if `c'==1  {
																	// If this is 1st contxt, record base filename onto which to build
				global wrapbld = "`fullname'"						// Need to use same name for global as used in 'spdtst' code, above
				global wraptemp = "`i_`c''"							// ('cos 'c'==1 this is first element of $wrapbld, on which we build)
*				local namloc =strrpos("`fullname'","`c(dirsep)'")+1	// Posn of first char following final "/" or "\" of directory path
				global savepath = substr("`fullname'",1,`namloc'-1)	// Path to final dirsep should be same for all successive files
																	// (no longer taken for granted; path ends with dirsep – "/" or "\")
				global nlst = 2										// Number of current list used to store tempfile names		
				local nlst = 2										// (numbered 2 for poor reason: it starts with the second context)
				local listlen = "listlen`nlst'"						// Stepping stone to having global ending with index#
				global `listlen' = 0								// N of names in first list of files to be appended (none as yet)
				local appendlst = "appendlst`nlst'"					// Local needed to refer to global with terminal index#
				global `appendlst' = ""								// Local (NOW GLOBAL) holds 1st list of tempfile names 
				local nnames = "nnames`nlst'"						// Ditto for n of names in list of files to append
				global nnames`nlst' = 0								// Local nnames`nlst' is used to record n of names in $appendlst#

			} //endif `c'==$
						
			
			else {													// Else `c' indicates context beyond the first (i.e. 'c'>1)
				
			   local thisname = substr("`fullname'",`namloc', .)	// Trailing name of file to hold data generatd for this context
			   local namlen = strlen("`thisname'")					// Get length of string holding 'thisname'			   
			   if $`listlen' + `namlen' > c(macrolen) {				// If length of resulting list of names would be > c(macrolen)
																	// (ax byte-length of a stata macro on this machine = 645,200 bytes)
				  local nlst = $nlst + 1							// Increment n of lists holding these names; resets `name#')
				  global nlst = `nlst'								// Avoids need for & in mid-word
				  local `nnames' = "nnames`nlst'"					// Local seemingly needed to access a macro with terminal index#
				  global `nnames' = 0								// For each filename-list this holds the N of names in that list
				  local listlen = "listlen`nlst'"					// Local seemingly needed to access a macro with terminal index#
				  global `listlen' = 0								// Zero the accumulated length in chars of next namelist
				  local appendlst = "appendlst`nlst'"				// Local needed to refer to global with terminal index#
				  global `appendlst' = ""							// Empty the next list of tempfile names

			   }
			   
			   global `listlen' = $`listlen' + `namlen' + 1			// Add up bytes used for this list of filenames (prhps many dblstkd)
																	// (same 'namlen' as was used above to check if space was enough)
			   global `appendlst' = "$`appendlst' `thisname'" 		// Append to current list (after the space counted as +1 above)
			   global `nnames' = $`nnames' + 1						// Store the position (word#) of the current name within this list
																	// (becomes a count of the n of filenames in this list)
		    } //endelse	`c'==1										// End of codeblk dealing with contexts beyond the first
																	
		  } //endelse 'spdtst'										// END OF CODEBLOCK THAT MINIMIZES N OF TIMES FILES ARE OUTPUT/USED
																	// (code above is executed only if we are NOT using 'spdtst' code)

						
	    } //endif !'skipsave'										// Just to make things even more complicated, either code version is
																	// only executed if command is not 'genplace' (unless w 'call' optn)
	  		
		
*		*******
		restore														// Here finish with working contxt, briefly restore full workng data
*		*******														// (briefly unless this is the final context)
 
	   
*	 *******************
	} //next value (`c')											// Repeat while there are any more contexts to be processed
*	 *******************
		
	

	


	
	if "`spdtst'"==""  {											// If we are NOT testing speed of simpler code ...
																	// ****************************************************************
global errloc "wrapper(8.1)"										// INCLUDE (8.1) IF MINIMIZNG N OF TIMES EACH CNTXT IS SAVED/USED	***
pause (8.1)															// ****************************************************************

	
										// (8.1) After processng last contxt (codeblk 7-8), post-process outcome data for mergng w orignl
										//	     (saved) data. AT THIS POINT THE DATA IN MEMORY ARE THE FULL WORKING DATA SUBSET
										
										
	  if !`skipsave'  {												// Skip this codeblock if conditions for executing it are not met
																	// (skipped only for genplace cmd with no 'call' option)
																	
		if "`multiCntxt'"!=""  {									// If there ARE multi-contexts (local is not empty) ...
																	// Collect up & append files saved for each contxt in codeblk (8)
																	// (If there was only one context then just one was saved)
		   preserve													// Need to preserve again so as to append contexts to $wraptemp file
//LATE ADDITION (DEC'25):			  
			  use $wraptemp, clear									// USE 1ST DATASET CONTAINING `cmd'P-PROCESSED DATA FOR FIRST CONTXT
//ENSURE ALL TEMPFILES ARE ERASED
			  local nlst = 2										// Start with the first list out of possible set of lists
			  local nname = 1										// Number (position) of this name in this list
			  local nnames = "nnames`nlst'"							// Local needed to access a macro with trailing index#
		   
			  forvalues i = 2/`nc'  {								// Cycle thru all contexts whose filenames need to be appended

				if `nname'>$`nnames'  {								// If 'nname' is beyond $nnames saved for this list in codeblk (8)
					local nlst = `nlst' + 1							// (so increment n of lists holding these names; reset `name#')
					local nname = 1									// The next tempfile will hold the first remaining context name
					local nnames = "nnames`nlst'"					// Local needed to refer to macro with terminal index#
				}
				
				local appendlst = "appendlst`nlst'"					// Local needed to refer to macro with terminal index#
				local a = word("$`appendlst'",`nname')				// Get name of this file in `appendlst'`nlst'; append context dta
				quietly append using $savepath`a', nonotes nolabel	//  to $wraptemp file using directory path to that contxt name
				erase $savepath`a'									// Erase that tempfile	($savepath ends with `dirsep')
				
				local nname = `nname' + 1							// Increment the position of next filename in this list
				local nnames = "nnames`nlst'"						// Local needed to refer to macro with terminal index#
				 
			  } //next 'i'
																			
			  quietly save $wraptemp, replace						// File $wraptemp now contains all new variables from `cmd'P
																	// (for all contexts, each context separately appended above)
		   restore													// Restore the working dataset for the final context
		
*		   erase $wraptemp											// Need to keep until after merge
																	// Erase this tempfile
		   
		} //endif `multiCntxt'										// If not a multicontext dataset the one file is all there is
	  
	  } //endif !'skipsave'											// (skipped only for genplace commands with no 'call' option)
	  
    } //endif 'spdtst'												// END OF CODEBLOCK THAT MINIMIZES N OF TIMES FILES ARE OUTPUT/USED
	
	
	

	
	
global errloc "wrapper(9)"	
pause (9)

												//		******************************************************************************
*  capture noisily {							// (9)  Recover `origdta', then the previous names of variables temporarily renamed to  
												//		avoid naming conflicts; merge new vars, created in `cmd'P, with original data
												//		******************************************************************************
												
												
*	*****************												
	if !`skipsave'  {										// Skip next codeblk if 'cmd' is 'genplace' without 'call' option
*	*****************



*	  ****************************										
	  quietly use $origdta, clear							// Retrieve original data to merge with new vars in $wraptemp 
*	  ****************************							// (vars built in 'cmd'P from vars in 'multivarlst)
															// If we skipped the saves, above, then we don't make any changes
															// (everything from codeblk 8 onward was just cosmetic in that case)

															

global errloc "wrapper(10)"
pause (10)	  



	  
*	  *****************	  
	  quietly merge 1:m `origunit' using $wrapbld, nogen update replace // Different name for same file as $wraptemp
*	  *****************										// Here merge the full working dta file w all cntxts back into `origdta'
															// (bringing with it the prefixed outcome vars built from 'multivarlst'
	  erase $wrapbld
															// This should be the final tempfile to be erased
	  
	  

	  

	  
/*															// COMMENTED OUT 'COS ALREADY DEALT WITH VARS THAT $exists		
													
*	  ************											// ************************************************************************* 
	  if "$exists"!=""  {  									// Got its contents in getprfxdvars <-- wrapper(5) 
*	  ************											// Holds list of varnames that conflict with those of new outcomes 
															// (these will be created in cmd's subprogram 'cleanup' before exiting `cmd'
															// *************************************************************************
		foreach var  of  varlist $exists  {
			capture drop `var'
		}

	  } //endif $exists
*/	  														// END OF COMMENTING OUT


	  
*	*********************	  
	} //endif !`skipsave'
*	*********************
	
	
	if "$busydots"!="" noisily display " "					// Override 'continue' following final busy dot(s)
	




	if "`cmd'"!="genstacks"  {								// Genstacks has its own cleanup codeblocks

*		************************				
		cleanup ,  `optionsP'								// Cleans up outcome data (labeling, rounding, prefixing, etc.)
											 				// (called w `optionsP' so it can parse the options for current command
		if "$SMreport"!=""  exit 							// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
*		************************							// 'SMreport' is only set by errexit, so this tells us there was an error

	}						
 
 
	local skipcapture = "skip"								// If execution goes thru this point there was no error in capture blocks
	

*  ************
} //endcapture												// Close brace matching the 'capture noisily {' at start of program
*  ***********
 

pause wrapper(11)
global errloc "wrapper(11)"


										// (11) Handle any non-zero return codes from above (including called programs)
										// 		Drop all globals except those needed by caller ('multivarlst') & succeeding commands

															
  if _rc  & "`skipcapture'"=="" & "$SMreport"=="" {			// If unreported non-zero return code (should be captured Stata error)
															// (meaning that nature of error will not already have been displayed)
	 errexit "Likely user error in $errloc"					// If no return code, likely user error
	 exit

  } //endif _rc & ...
															// (option 'display' sends msg to console as well to stopbox)
															// (any call on errexit sends msg to stopbox)
																														
    if "$SMreport"==""	{									// Lack of $SMreport means did not already tidy up; do so now ...
															// Drop all globals, restoring those needed by succeeding stackMe commands
	  scalar origdta = "$origdta"							// Ditto for $origdta
	  scalar multivarlst = "$multivarlst"					// Ditto for $multivarlst
	  scalar limitdiag = "$limitdiag" 						// And for $limitdiag
	  scalar SMreport = "initialized"						// Need this work-around in case "$SMreport was never set non-empty
	  scalar SMreport = "$SMreport"							// (an undefined scalar cannot be defined by assigning it an empty global)
	  capture confirm number $SMrc
	  if _rc  {												// If not a numeric return code
	  	if "$SMrc"=="" global SMrc = ""						// If empty ensure it is initialized
	  }														// (leave unchanged if not empt)
	  macro drop _all										// Drops above globals (along with many others and all locals) before exit
	
	  global origdta = origdta								// Global origdta is needed by caller programs, re-entered on 'end' below
	  global multivarlst = multivarlst						// Ditto for $multivarlst (used in many caller programs)
	  global limitdiag = limitdiag							// And for limitdiag (used ubiquitously)
	  if SMreport !="initialized" global SMreport =SMreport // And $SMreport, if its scalar's "initialized" flag has been replaced
	
	  scalar drop _all										// Drop all scalars before exit
	  
	  capture drop ___*										// Drop all quasi-temporary vars
	  exit 0												// Exit with return code 0 even if there were no tempvars to drop
	
    } //endif $SMreport 									// ABOVE DROPS scalars VARLISTS#, PRFXVARS# & PRFXSTRS BUT WE CAN KEEP
															// PARSING $multivarlst AS WE DO NOW	

	
end //stackmeWrapper										// Here return to `cmd' caller for data post-processing




************************************************* end stackmeWrapper ****************************************************************








**************************************************** BEGIN SUBPROGRAMS **************************************************************
*
* Table of contents
*
* Subprogram			Called from						Task & notes (just one argument in quotes unless otherwise noted)
* ----------			-----------						------------
* checkSM				Wrapper(2.2)					Establish list of SMvars (a.k.a. special names) referenced by user
*													 Note: "text" [or "noexit"] prevents call on 'errexit' from 'checkSM' on error
* checkvars				Wrapper(2.2), subprograms 		Alternative for unab that handles mixed hyphenated and abbreviated varnames
*													 Note: "text" [or "noexit"] prevents call on 'errexit' from 'chackvars' on error] 
* cleanup				Wrapper(10) except genstacks	Cleans up outcome data after processing (labeling, rounding, prefixing, etc.)
* dispLine				Wrapper, showdiag2, others		Displays text in Results window with optimized line-breaks
* errexit				Everywhere						Displays error msg in 'note' window; optionally also in Results window 
*													 Note: arg "msg" | opts , msg(required) rc() display(reqrd to display msg)
* getoutcmnames			getprfxdnames, cleanup 
* getprfxdnames			Wrapper(5); cleanup(10)			Initialize outcome variables as required by each command
*													 Note: outcomes, options lets program identify optioned outcome prefix-strings
* getwtvars				Wrapper(2)						Establish weight string for each nvarlst in a multivarlist
* isnewvar				Wrapper(various)				See if vars [w optioned prefix-string] already exist
* showdiag1				Wrapper(6)						Store diagnostic stats before calling 'cmd'P
* showdiag2				Wrapper(7)						Display diagnostic stats after return from 'cmd'P
* subinoptarg			unsure if called at all			Shorthand way to replace argument within option string
* stubsImpliedByVars	genstacksO (twice)				Name says it
* varsImpliedByStubs	genstacksO, cleanup				Name says it
*
********************************************************************************************************************************




capture program drop checkSM						// Called from stackmeWrapper (SMvars should be read as SMnames)

program define checkSM, rclass						// Checks whether varlist creates any SMname vars (special names) & their linkags
													// (those names should match already extant varnames)

local errloc = "$errloc"
gettoken caller rest : errloc,  parse( "(" )					  // Local `caller' gets name of program that called this subprogram
global errloc "checkSM"											  // Establish general location of any error that may be found below

   args check noexit											  // Argument 'check' contains list of non-'unab'ed variables	
																  // Arg 'noexit' forces return to caller on error
																  
   capture noisily {											  // Open braces enclose code within which any error will be captured
																  // (and processed after the matching close braces)
	  local SMerrs = ""
	  local SMnames = ""
	  foreach var of local check  {
	  	 if substr("`var'",1,2)=="SM"  {
			if "`var'"!="SMitem" & `var'!="S2item"  {
			   local SMerrs = "`SMerrs' `var'"
			}
			else local SMnames = "`SMnames' `var'"			  	  // List of 'SMitem', 'S2item' found in user-supplied varlist
		 } //endif 'substr'
	  }
	  
	  if "`SMerrs'"!=""  {
	  	 errexit "SMitem(s) named in varlist should be 'SMitem' or 'S2item, not `SMerrs'"
*				  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		 exit
	  }															  // If no exit, `SMerrs' is still empty to be filled below  

	  if "`SMnames'"==""  {										  // These are user-optioned SMnames validated above
		 return local gotSMvars `SMnames'	  					  // Return empty list and exit (emptyness is irrelevant to caller)
	  	 exit													  // (`gotSMvars' & `SMnames' will both be empty if there are none)
	  } //endif
	  

	  local SMvar = ""											  // List of SMitem or S2item found in user-optioned 'check'
	  local SMbadlnk = ""										  // SM/S2 items whose link does not exist ditto

	  foreach var  of  local SMnames  {						  	  // Cycle thru one or both of SMitem, S2item held in `SMvars'
																  // (we only reach this point if `SMnames' is NOT empty)
		 local item = "`_dta[`var']'" 	  						  // Retrieve associated linkage variable from data characteristic
		   
		 if "`item'" ==""  {
			local SMerrs = "`SMerrs' `var'"					  	  // If SMitem isn't linked, extend list of unlinked SMvars
		 }														  // (we only reach this point if `SMerrs' IS empty)
		 
		 else  {												  // Else `item' is not empty
			capture confirm variable `item'				  	  	  // Check if link is to an existing variable
			if _rc  {											  // See if it names an existing variable
			   local SMbadlnk = "`SMbadlnk' `var'"			  	  // If not, extend list of bad links
			}
			else  local SMvar = "`SMvar' `item'"		  		  // Else extend list of vars linked to `SMitem' or 'S2item'
			  
		 } //endelse
		 
		 if wordcount("`SMnames'")==1 & word("`SMnames'",1)=="S2item"  local SMvar = "null `S2var'"
																  // If only 'S2var' was named, put "null" word in front of it
	  } //next 'var'
		
	  if "`SMerrs'"!="" | "`SMbadlnk'"!=""  {					  // If there are any unlinked SMvars
		
		  if "`SMerrs'"=="" & "`SMbadlnk'"!=""  {				  // If error is due to absent linkage characteristic(s)
			  errexit "stackMe special name(s) `SMerrs' have no linkage characteristic(s)"
			  display as error "See help SMutilities##SMutilities:{ul:SMvars} for details"
			  exit
		  }
		  
		  else  {												  // Else error must be due to link failing to name existing var
			  if wordcount("`SMvars'")>1 {
			  	 errexit "stackMe special names `SMerrs' are not linked to existing variables"
*						  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  }
			  
			  else  errexit "stackMe special name `SMerrs' is not linked to an existing variable"
*							 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  display as error "See help SMutilities##SMutilities:{ul:SMvars} for details"
			  exit
		  } //endelse											  // (Should never emerge from this else with existing code)
		   
	  } //endif `SMerrs' |`SMbadlink'
		
	  else  {												  	  // Else each SMname (if >1) is linked to an existing variable
	  
		 local i = 0
		 foreach str in SM S2  {								  // Cycle thru 'SM' and 'S2' prefixes to word 'item'
			local i = `i' + 1
			local item = word("`SMvar'",`i')					  // If either word is empty it must be that 'S2item' is missing
			if "`item'"==""|"`item'"=="null"  continue			  // If this SMvar word is empty or null, continue with next word
			replace `str'item = `item'	  					  	  // NOTE that 1st 'item' is 2nd half of varname; 2nd IS a varname
		 }													  	  // (So SMitem, if named, is var with obs copied from linked var)
																  // (ditto for S2item, if user named it in varlist)
	  } //endelse "`SMerrs										  // (NOTE SMitem AND wtvar ARE ONLY TWO LISTS WITH MEANNGFUL "null")
	  
/*		
	  if "`gotSMvars'"!=""  {									  // Confirmed to exist by above code
	  	if "`allSMvars'"!=""  {									  // Found to exist before that
		  foreach v  of  local gotSMvars  {
			 local allSMvars = subinstr("`allSMvars'","`v'","",.) // Replace each `v' of gotSMvars found in 'allSMvars' with ""
		  }														  // (removes from allSMvars any SMvars identified above)
		}														  // (so that we know what SMvars remain that could be cmd-specific)
	  }

	  global cmdSMvars = "`allSMvars'"					  		  // Remaining SMvars should be command-specific  
*/																  // (miscount and misplugcount – perhaps not for current cmd)			***
	  return local gotSMvars `SMvars'		  					  // List of specified SMvars found above ()
	  
	  local skipcapture = "skip"
	  
	  
	  
	  
*  *******************	  
   } //endif 'capture'
*  *******************
  
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
   }
   
														
end checkSM



********************************************************************************************************************************


																	 
capture program drop checkvars					// Called from wrapper and several subprograms; elaborates unab
												// (Should be renamed 'unablist' for "unab list of vars")
		
program checkvars, rclass						// Checks for valid input/outcome vars. Partially overcomes intermittant
												//  error when unab is presented with a hyphentated list of varnames
												// (with hyphentd AND non-hyphenated it can wrongly send non-zero return code)
												// ("partially" because 'unablist' exits on first bad 'var-var' varlist, whereas
												//	the whole point of this subprogram is to build a list of all bad varnames)
												// In practice all bad varnames are listed unless interrupted by bad var-var
local errloc = "$errloc"
gettoken caller rest : errloc,  parse( "(" )					// Local `caller' gets name of program that called this subprogram

global errloc "checkvars"										// Establish general location of any error that may be found below

																// ORIGINALLY SENT varlist AS ARGUMENT, BUT THAT COULDN'T HANDLE PREFIXS
*	args check noexit											// IF 1ST VARNAME IN 'check' IS PREFIXED, IT IS TAKEN AS THE ONLY VAR	***
																// (may include hyphenated varlist(s))
																
*	****************	
	capture noisily {
*	****************

	local anything = `0'										// Retrieve `anything' from `0', where 'syntax' expects to find it
																// (substituting a null string for each double quotion markl)
	if word("`anything'",-1)=="noexit"  {						// If last "var" in any varlist is "noexit", that is NOT a variable
		local noexit = "noexit"									// (so put it in the local where this subprogram expects to find it)
		local check = subinstr("`anything'","noexit","",1)		// And substitute null string for `noexit' string and put rest in `check'
	}															// (where the rest of this subprogram expects to find it)
	else  local check = "`anything'"							// If no `noexit' trailing arg, put all of `anything' into `check'
	

	local errlst = ""											// List of invalid vars and invalid hyphenatd varlsts
										
	if strpos("`check'","-")==0  {								// If there are no hyphenated varlists
		foreach var  of  local check  {							// Cycle thru un-hyphenated vars in varlist
			capture unab var : `var'							// If 0 not returned then variable does not exist
			local rc = _rc										// Not sure if _rc persists beyond next command
			if "`var'"=="."  continue							// If `var' is missing continue with next var
			if `rc'  {											// Else if the `rc' saved just above is non-zero..
				local errlst = "`errlst' `var'"					// Add that invalid var to 'errlst' if not missing
			}
			else local checked = "`checked' `var'"				// Else add that valid `var' to 'checked'
		} // next `var'
	} //endif 'strpos'
		
	else  {														// Else there are one or more hyphenated varlists
		
		local chklist = "`check'"								// Want to keep 'check' untouched for SM search, below
		local checked = ""										// {portion of }
																
		while strpos("`chklist'","-") >0  {						// While there is an(other) unexpanded varlist in 'chklist'
																// (chklist has 'head' to 'test2' removed at end of 'while')
			local loc = strpos("`chklist'","-")					// Find loc of hyphen that defines the list
			local head = substr("`chklist'",1,`loc'-1) 			// Extract string preceeding hyphen
			local test1 = word("`head'",-1)						// Extract last word in 'head' (word before hyphen)
			local tail = strtrim(substr("`chklist'",`loc'+1,.))	// Extract string followng hyphen (may contain another "-")
			local test2 = word("`tail'",1)						// Extract the 1-word varname following the hyphen
			local test3 = word("`tail'",2)						// Word following `test2', if any
			
			local t1loc = strpos("`chklist'","`test1'")			// Get loc of first word in hypnenated varlist
			if `t1loc'>1  {										// If there are vars before 'test1', evaluate those
			   local pret1 = substr("`chklist'",1,`t1loc'-1)	// These vars end before 'test1'; put them in 'pret1'
			   foreach var  of  local pret1  {					// And evaluate each one
			   	  capture unab var : `var'						// If 0 not returned...
				  if "`var'"=="."  continue						// if `var' was returned missing, continue with next var
				  if _rc  local errlst = "`errlst' `var'" 		// Add any invalid varname to 'errlst' if not missing
				  else  {
				  	local checked = "`checked' `var'"			// Else add the valid varname to `checked'
				  }
			   }
			}								
			local t12vars = "`test1'-`test2'"					// 't12vars' will be string "'test1'-'test2'" inclusive

			capture unab t12vars : `t12vars'					// Put the unabbreviated list of vars into `t12vars'
			if _rc {
				errexit "Cannot unabbreviate `t12vars' – perhaps one or more don't exist?"
				exit											// In this case, override `noexit' argument, if any
			}
			local checked = "`checked' `t12vars'"				// String of checked vars up to end of var `test2'
			
			if "`test3'"!=""  {									// If "`tail'" holds anything beyond end of hyphenated list
				local loc = strpos("`tail'","`test3'")			// Get loc of start of that remaining tail (after any blanks)
				local chklist = substr("`tail'",`loc', .)		// Put remaining tail (following any blanks) into checklist
			}
			else  continue, break								// If `test3' is empty, break out of while loop
			
			if strpos("`chklist'","-")  continue				// If it contains another hyphen, continue with that
			
			
			foreach var  of  local chklist  {					// Otherwise check validity of remaining vars

			   capture unab var : `var'
			   if "`var'"=="."  continue						// If var was returned missing, continue with next var
			   if _rc  {
				  local errlst ="`errlst' `var'" 				// If _rc !=0 add any invalid vars to 'errlst'
			   }
			   else  {											// THESE BRACES ARE NEEDED, OR STATA DISREGARDS 'else'	?				***
				 local checked = "`checked' `var'"				// Else add to list of checked vars
			   }

			} //next var
			
		} //next while
			
	} //endelse	`strpos'										// End of codeblock dealing with hyphated varlist(s)
		
	if "`errlst'"!=""  {										// If any bad varnames were identified ...
		
		dispLine "Invalid variable name(s): `errlst'" "aserr"	// May need multiple lines to display this error message
		if "`noexit'"==""  {									// If `noexit' was not optioned on call to this subprogram..
			errexit, msg("Invalid variable name(s): `errlst'")	// Then exit with stopbox message but no addtional display
			exit												// 'errexit' w opt & w'out ',display' suppresses display
		}														// Else return errlst to caller (next command after endif)
	} //endif
		
	return local errlst `errlst'								// If not empty would already have caused an error exit
	return local checked `checked'								// Return unabbreviated un-hyphenated vars in r(checked)
																// (not clear we need to do this)
	local skipcapture = "skip"

		
		
		
*	 *************	
	} //endcapture
*	 *************
	
	
    if _rc & "`skipcapture'"==""  {
   	   errexit "Error in $errloc"
       exit
    }
														
	

end checkvars




********************************************************************************************************************************





capture program drop cleanup			// Subprogram that performs final tidying of outcome variables: label each variable and
										// (for gendummies) each value; enumerate vars with all-missing values to be skipped; 
										// create or update SMmisval & SMplugmisval variables; round and bound vars as optioned; 
										// rename `cmd'P-generated interim variables.
										
										
										// **************************************************************************************
										// As we enter this subprogram, context-specific working data have been processd by `cmd'P
										// for the current command and merged back into the original dataset. But `cmd'P-generated
										// interim vars still need to be first labeled and then renamed, if needed, to take account 
										// of user-optioned name prefixes; after which existing vars with "___" prefixes, given to 
										// avoid naming conflicts, need those prefixes removed. So program maintenance needs careful 
										// attention to which varnames are at what stage in the renaming process. As far as possible 
										// `cmd'P-generated interim names are used until the final stage of renaming; but note that 
										// the global list of $outcmnames is fully prefixed from the start (done before cmd-P proces-
										// sing so we could check for potential naming conflicts before processing any data).
										// **************************************************************************************
									
	
program define cleanup



*	*******************************															
	syntax , [ $mask  * ] // Re-parse the mask for whichever 'cmd' is currently in progress
*	*******************************							// Options like `dprefix' `itemname' and `round' are acquired in this way
															// NOTE THAT WHILE OPTIONS MOSTLY REMAIN UNCHANGED OVER SUCCESSIVE VAR-
															// LISTS, SEVERAL COMMANDS ALLOW THE FIST OPTION (WHATEVER IT MIGHT BE)
															// TO BE ESTABLISHED OR UPDATED BY A VAR-PREFIX PREPENDED TO THE FIRST 
															// VARNAME – PERHAPS ITSELF PREFIXED BY A PREFIX-STRING, THUS:)
															// [[strprfx_][prfxvar(s) :] varlist [if][in][wt] [,options]

	
local errloc = "$errloc"

															
															// RETRIEVE LOCALS THAT ONCE WERE GLOBALS BUT ARE NOW SCALARS
local outcmnames = OUTCMNAMES								// Retrieve input & outcm names from global saved by subprog 'getprfxdvars'	
local inputnames = INPUTNAMES								// ('getprfxdvars' got these lists from 'getoutcmnames' as r(return)s
local prfxnames = PRFXNAMES									// Prefix, if any, corrspnding to input (from subprogram 'getoutcmnames')
local spfxlst = SPFXLST										// List of prefixes that distinguish interims from inputs
															// (don't confuse with `strprfx'; derived from scalar set before wrapper(3))
local statprfx = STATPRFX									// Scalar stored after wrapper(3)
local statrtrn = STATRTRN									// Ditto
local namechange = "$namechange"
local cmd = "$cmd"



*pause on
										
pause cleanup(0)											// Establish general location of any error that may be captured below
global errloc "cleanUp(0)"									// Currently executing codeblock helps diagnose program & user errors




										// (0) Extract the option-string from the commandline for this command, run the 'syntax'
										//	   command on that string to make user options accessible to this subprogram
										
* *****************
  capture noisily {											// Open brace for codeblocks where errors will be captured, to be
* *****************											//  processed following the matching close brace at and of subprogram




pause cleanup(0.1)
global errloc cleanup(0.1)	

									
										//(0.1) Reduce all prefix-strs to single- or double-char; then prepare for labeling vars 
										//		appropriately, given input and outcome characteristics (these options remain in force 
										//		for all varlists used in this cmd (any updating of the first option for each command 
										//		will be handled seperately for each var-list, below).
										
										
										
	local ic = substr("`cmd'",4,1)							// Identifying char(s) used to distinguish interims produced by each `cmd'P
	if "`cmd'"=="gendummies" | "`cmd'"=="genmeanstats"  local ic = substr("`cmd'",4,2) 
															// (for `cmd'=="gendist `ic' is "d"; for `cmd'=="gendummies" `ic' is "du")
															// (but `ic' for 'genmeanstats' we will two chars identifying each stat)
															// local ic2 will be established per interim prefix
												
	if "`cmd'"=="gendist"  {								// If this is a 'gendist' command, prepare label content appropriately
	
		local mis = "`missing'" 							// Get missing treatment optioned by user with option `missing'
		if "`mis'"=="" local mis = "all"					// Defaults to "all" if 'missing' option was not used for any of above
		if "`mis'"=="mean" local mis = "all"				// Permit legacy keyword "mean" for what is now "all"
		if "`mis'"!="dif2" local mis = substr("`mis'",1,4)  // Keep 4 chars if those are "dif2", else just 3 chars
		if "`mis'"=="di2"  local mis = "dif2"				// (in case user thinks there is a 3-char minimum)
		if "`mis'"=="dif" local mis = "diff"				// (ditto)
		
	} //endif `gendist'

	local non2missing = ""									// List of vars not missing across all varlists (for efficiency)
	local nonmissing = ""									// Ditto across current varlist (UNSURE WHY THIS IS A GLOBAL)				***
	local skipvars = ""										// List of vars missing for all contexts, cumulates across varlists
															// (needed to eliminate all-missing variables from the data)

	
	
	
	

pause cleanup(0.2)							
global errloc cleanup(0.2)
	
										// (0.2) Discover what prefixes will have been used for interim variabls generatd by this cmd's
										//		 `cmd'P subprogram. Determine if any of them are all-missing for all contexts, so that
										//		 such vars can be skipped for the remainder of this `cmd' (also used for diagnostics).
										//		 Establish various foundations on which to build outcome variable labels. Display 
										//		 optioned choices regarding `replace' optn; 
					
					

	local statlist = "`statrtrn'"							// r(return) names for 'genmeanstats' repurposed to label 'genme' variables
															// (set after wrapper(3); used in cleanup(1.3))
	if "`cmd'"=="genmeanstats"  local spfxlst ="`statprfx'" // If this is a 'genme' cmd, labeling items from "$statrtrn", set after above
	local uniqnames  : list uniq inputnames					// Used for varlabels that only need one instance of each input var
	local uniqspfx   : list uniq spfxlst					// Used to cycle thru all distinct prefix strings & for checksum test, below															
															
	local interims = ""										// NEXT CODEBLK WILL PRODUCE `cmd'P-GENERATED INTERIM NAMES FOR THIS LIST

	
	local k = 0												// Index needed to access 'gendu'-produced "$interims" and for checksum test
	
	if "`cmd'"=="gendummies"  local interims = "$interims"	// 'gendu' is the only stackMe command to globalize its interim names
	
	else  {													// For other commands the list of interims has to be constructed
	
	   foreach name  of  local uniqnames  {					// Cycle thru all distinct input names
		  foreach spfx  of  local uniqspfx  {				// Cycle thru all distinct prefix strings (only "du_" for gendummies)
			 local interim = "`spfx'_`name'" 				// These `cmd'Ps just prepend `spfx' to front of "_`name'"
			 local k = `k' + 1								// SEEMINGLY NOT NEEDED														***
			 local interims = "`interims' `interim'"		// Cumulate the needed list of `interims' (interim is `spfx'_`name')
*			 local ic2 = "`spfx'"							// REDUNDANT
		  } //next `spfx'
	
	   } //next `name'
		
	   local noutcm = wordcount("`outcmnames'")				// As a check, count n of outcome names (should be same as n of interims)
	   local ninterims = wordcount("`interims'")
	   if `noutcm'!=`k'  {	
		   errexit "Checksum error: count mismatch in cleanup(0.2)"
		   exit
	   }

	} //end else
	
	
	
	

	
pause cleanup(1)
global errloc cleanup(1)	


											// (1) HERE PREPARE TO GET PROXIMITIES FROM DISTANCES & DISPLAY USER CHOICES
	


	local prx = 0											// Whether `proximities' was optd (DONT CONFUSE WITH `pfx' FOR PREFIX)
	
	if "`proximities'"!=""  {								// This codeblk applies only to command 'gendist'
		
		local prx = 1										// Proximities will be generated in next codeblk (1.1)
			   
		if "`replace'"!=""  {
			noisily display "Will calculate proximities as optioned; dropping distances per 'replace' option"
*					 		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		}
		else noisily display "Will calculate proximities as optd; distances kept since 'replace' was not optd"
	   
	} //endif 'proximities'									// Back to all 'cmds' (including 'gendist')
	

	else  {													// Else proximities are not being calculated
	   if "`replace'"!=""  noisily display "Dropping relevant input variables following 'replace' option"
	}														// Applies to all but 'gendist' command	

/*	
class_A1 class_A2 class_A999 class_B1 class_
> B2 class_B3 class_B999 du_classC1 du_classC2 du_classC3 du_classC996 du_clas
> sC999 du_classD1 du_classD2 du_classD4 du_classD5 du_classD999 du_COUNTRY27"
> )	  																				=18: INDEED WHAT WAS GENERATED BY 'gendummiesP'
*/	
 	   
	   
	   
	   
	   
	   
							
pause cleanup(1.1)
global errloc cleanup(1.1)	

										// (1.1) Create default label based on label of input var, if not command-specific
										
										
	local varlistno = VARLISTNO								// Scalar set in 'getoutcmnames' listing varlist# where each var was found
	
	local k = 0												// Current position in list of interims (also of inputs and outcomes)

	foreach interim of local interims  {					// Cycle thru' all vars generated by this cmd's `cmd'P subprogram
		
	  local k = `k' + 1										// Increment the above-mentioned varlist #
	  
	  local nvl = word("`varlistno'",`k')					// `varlistno' holds varlist# from which each var was derived
	  
	  local multivariate = MULTIVARIATE						// By default take user-optnd `multivariate flag' (put in scalar in wrappr)
	  
	  if "`multivariate'"!=""  local dvar = "`depvarname'"
	  
	  if MULTIVARIATE`nvl'!=""  local multivariate = MULTIVARIATE`nvl' // But check for `nvl'- specific scalar, put there pre wrappr(3)
	  
	  local prfxvars = PRFXVARS`nvl'						// Get prefixvars, if any, associatd with varlstno that yielded this interim
	  if GOTAT`nvl'!="" local prfxvars = GOTAT`nvl'			// For multivariate 'genyh' prefixvar is in scalar GOTAT`nvl'
	  
	  if "`prfxvars'"!=""  {								// If prefixvar is non-empty ..
	    if "`cmd'"=="genyhats"  local dvar = "`prfxvars'"
		
	    local strprfx = PRFXSTRS`nvl'						// get any prefix string that may have prefixed the prefixvar
		if "`strprfx'"=="."  local strprfx = ""				// If missing make it empty
		if "`cmd'"=="genyhats"  {							// For 'genyhats'..
		   if "`strprfx'"=="yh"  local strprfx = "yd"		// make the outcome name more specific
		}													// (else, for 'genii', prefixvars were used to generate outcomevars)
	  }	//endif `prfxvars'									// Else it is a bivariate yhat (unless user option overode default)


	  if strlen("`ic'")==2  local ic2 = "`ic'"				// Handles existing 2-char `ic's (for 'gendu' and 'genme)
	  else  local ic2 = ""
	  if strlen("`ic'")==1  local ic2 = "`ic'" + substr("`interim'",1,1) // This two-char `ic' appends interim prefix to cmd prefix
															// (for commands that don't already have a two-char `ic')
															// (don't confuse with 2-char `ic' used elsewhere for gendu and genme vars)
      local lbl = ""										// Will hold default label for each var in turn
	  
	  local iname = word("`inputnames'",`k')				// Get the input name corresponding to this interim
	  if "`iname'"=="."  local iname = ""					// If `iname' is missing, make it empty

*	  ***************************************************	   
	  if "`iname'"!=""  local lbl : variable label `iname'	// Basis for most outcome var labls is the existng label for corrspdng input
*	  ***************************************************	// (so we use `name', which had any gendummies suffix removed above)

	  if "`lbl'"!=""  {										// If that variable characteristic exists
	  	
	    capture confirm number "`lbl'"
	    if _rc  {											// If return code is not zero then `lbl' is not all-numeric
	   
	      if "`lbl'"!=""  {									// If input variable was labeled
		  	local lbl1 = "gen`ic2'-generated outcome from input `iname': `lbl'"
															// Append that label
		  } //endif `lbl'o
		} //endif _rc
	  } //endif `lbl'	
															// Else input var was not labeled, so make label less specific
	  else  {

		local lbl1 = "gen`ic2'-generated outcome from input `iname'"
												
	  } //endif
															// ONE MORE SPECIAL CASE TO BE PROCESSED BEFORE inputs FROM OTHER CMDS:
	  if "`cmd'"=="genyhats" & "`multivariate'"!=""  {		// If this is a multivariate yhats command
															// (PROCESSED FIRST `COS COMES IN 2 FLAVORS – `bivariate' version below)
		   local varlist = VARLISTS`nvl'	  				// (`nvl' is the 'foreach' local that increments for each varlist)
		   local lbl : variable label `dvar'
		   local lbl1 = "Yhat for regressn of `dvar' on `varlist'" // `uniqnames' omits duplicate inputs (eg in gendu)
*					 	 12345678901234567890123456789012345678901234567890123456789012345678901234567890
															// HERE INSERT CODE TO PUT (ABBREVIATED) DEPVAR LABEL IN PAREN BEFORE "on"	***																
	  } //endif `cmd'										// (BIVARIATE GENYHATS will be processed as final labeling cmd, below)

	
	

	
pause cleanup(1.2)
global errloc cleanup(1.2)										
	
											
										// (1.2) Here appropriately label outcome variables for remaining commands
										//		 (based on label for input var, if that var is labeled)
									
		  
	  if substr("`interim'",1,2)=="m_"	{					// Same code should work for all commands that produce an m_ outcome
		 local lbl1 = "Whether variable `iname' was originally missing" 
	  }
									
	  if "`cmd'"=="gendist"  {								// `cmd' 'gendist' is also responsible for generating proximities
			 
		 if substr("`interim'",1,2)=="d_"	{				// This `interim' is a distance measure
		  
		    local distance = "`interim'"					// Save this value to use when generating any optioned proximity
			local lbl1 = "Distance of `selfplace' from `mis'-based `iname'"
*					 	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			if "`lbl'"!=""  {
			  local lbl1 = "Distance of `selfplace' from `mis'-based `iname': `lbl'"
			}
		   
		  } //endif substr
		  		  
		  
		  if substr("`interim'",1,2)=="p_"  {
			 local temp = "`mis'-based plugging values for var `interim': `lbl'"
			 local lbl1`' = strupper(substr("`temp'",1,1)) + substr("`temp'",2,.)
		  }
		  
		  
		  if substr("`interim'",1,2)=="x_"  {				// If proximities were optioned on a gendist cmd 
															// (equivalent to testing for substr(`interim"1,2)=="x_'))
	   		 quietly sum `iname'							// Get missingness from source of proximity, which is distance
			 scalar MAX = r(max)							// Store maximum value of this source iname
*			 *******************************************
			 quietly replace x_`iname' = MAX - `distance'	// Newly-created vars receive prefixes according to function
*			 *******************************************	// (`distance' is a saved copy of the d_ version of `interim'
			 local lbl1 = "Proximity of `selfplace' to `mis'-based `iname': `lbl'"

			
		  } //endif `prx'
				
	  } //endif `cmd'=="gendist'							//END OF CODEBLK DEDICATED TO LABELING DISTANCES AND PROXIMITIES
	   
	   
	   
	  if "`cmd'"=="gendummies"  {
	   	
	   	 if "`lbl'"!=""  {									// If the input variable was labeled..
		  	local lbl1 = "`lbl1': `lbl'"					// Use that label to extend the generic (default) label from codeblk 1.2
		 }

	  } //endif `cmd'==gendummies
		  
		  
	  if substr("`interim'",1,1)=="."  continue				// CONTINUE WITH NEXT INTERIM IN THIS CASE (CLUGE AS TEMP FIX FOR UKNOWN)	***
				  
				  
				  
				  
				  
*pause on			
pause cleanup(1.3)
global errloc cleanup(1.3)

										// (1.3)	Now we have the "root" input var, if any, we get to our actual outcome vars
										//			(gendist and gendummies outcomes have already been labeled); we continue with
										//			 other commands in alphabetic order of their i.c.'s (identifying character(s))
				  
												
	  if "`cmd'"=="geniimpute"  {							
	  	
		 if substr("`interim'",1,2)=="i_"  {				// Remove 'interim' from list of vars used to impute it
															// (and make the result part of `lbl1')
			local lbl1 = "Missng values imputd from "+stritrim(subinstr("`uniqnames'","`interim'","",1))
			if strlen("`lbl1'")>73 & "`addvars'"!=""  local lbl1 = substr("`lbl1'",1,73) + ".. `addvars'"
			if strlen("`lbl1'")>80  local lbl1 = substr("1,78") + ".."
															// Put result in `lbl1' to be applied below
		 } //endif		
															// Interim with m_ prefix was already labaled in cleanup(1.2)
	  } //endif `cmd'
			   
	
	  if "`cmd'"=="genmeanstats"  {							// This command has a different basis for its `ic' prefixes
								  
		  local lpfx = word("`statlist'",`k')				// `lpfx' is repurposed as a portion of the label for a 'genme' var
															// (`statlist' was got from "$statrtrn" in cleanup(0.2) (now `statrtrn')
		  if "`lpfx'"=="sweights" local lpfx = "SumOfWts"	// If optd stats include sum of weights, correct the label portion
		  if "`lpfx'"=="sd" local lpfx = "StdDev"			// Ditto regarding "sd"
		  if "`lpfx'"=="n"  local lpfx = "NofObs"			// Ditto regarding "n"
		  if "`lpfx'"=="np"  local lpfx = "NofObs"			// Ditto regarding "n"  (both versions exist in different codeblocks)

		  local lbl1 = strupper(substr("`lpfx'",1,1)) + substr("`lpfx'",2,.) + " for var `iname': `lbl'"

	  } //endif 'cmd'=="genmeanstats"
  
						
	  if "`cmd'"=="genplace"  {
				
		 display as error "labeling not yet implimented for genplace"	
															// WILL BE FILLED IN WHEN CODE FOR CMD 'genplace' IS FINALIZED			***
	  } //endif `cmd'
			   
			     
	  if "`cmd'"=="genyhats" & "`multivariate'"=="" {		// If this is a bivariate genyhats analysis
															// (the d_`var' was labeled at end of codeblk 1.1)
		  local lb2 : variable label `iname'				// Basis for outcm var labels is the existng label for corrspndng input
		  
		  if "`lbl2'"!=""  local lbl1 = "Yhat for regression of `iname' on `depvarname':`lbl2'"
*					 					 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		  else  {
		  	 local lbl1 = "Yhat for regression of `iname' on indep `depvarname'"
		  }
					
	  } //endif `cmd'										// End of codeblks for var with existing label
	

		
		
	  
															
	  if "`lbl1'"!="" 	{									// IF `lbl1' IS NOT EMPTY, TRUNCATE IT AS NEEDED TO FIT ON AN 80-COL LINE
															// (if IS empty this will be because this interim does not get a `lbl1')
		  if strlen("`lbl1'")>80  local lbl1 = substr("`lbl1'",1,78) + ".."
	  }
	  else local lbl1 = "Outcome based on original input variable `iname'"	
															// Else use this fallback label when none other has been prepared above
	  
	  
*	  ****************************							// *************************************************************************
	  label var `interim' "`lbl1'"							// THIS IS WHERE INTERIM VARS RECEIVE THEIR LABELS (kept when renamed below)
*	  ****************************							// *************************************************************************
*								

	

*pause on
		
pause cleanup(2)
global errloc cleanup(2)
pause off			
										// (2) Prepare lists of variables with no obs in any context, to be skipped as we proceed

			
															// AS WE PROCEED..
	   quietly count if !missing(`interim')					// Make list of all-missing interims – counts are for the entire dataset
	   if r(N)==0  {										// (unlike the counts by context made in  'showdiag2'<-'stackmeWrapper')		
		  local skipvars = "`skipvars' `interim'"			// 'skipvars' has names of `cmd'P-genrtd interms with no obs in any contxt
	   }													// (`skipvars' cumulate across varlists for use in 'cleanup'(10.3))
															
	   if strpos("`skipvars'","`interim'")  continue		// Continue with next interim if this one has no observations in any context
															// (we use 'name' in case this was a 'gendummies' command)			
															// (note that we don't prefix names added to `skipvars' list)
	   else local non2missing = "`non2missing' `interim'"	// (GLOBAL nonmissing SEEMINGLY NO LONGER FUNCTIONAL IN THIS SUBPROGRAM)	***
															// (`non2missing' originally was distinguishd by applying to all varlists)
	   
		
*	****************			
	} //next 'interim'										// Continue with next `cmd'P-generated interim variable
*	****************


															// (`non2missing' is legacy from when we took each varlist separately)
	local skipvars : list uniq skipvars 					// (Still here in case we later revert to that - more consistent - code)
	
	local nvars : list sizeof non2missing					 // `non2missing' relates to vars across all varlists
	  
	local ic = substr("`cmd'",4,2)							 // Identirying char(s) for `cmd'P-generated interim vars for current cmd
	if "`cmd'"=="gendummies"  local ic = "du"				 // For these named commands, override the prefix established just above
	if "`cmd'"=="genyhats"  local ic = "yi"
	if "`multivariate'"!="" local ic = "yd"
		  
	if "`cmd'"!="genmeanstats"  {							// (missingness is tracked for all other stackMe commands)
															// (gendi's missing options were processed near top of cleanup(1))
	  if "`cmd'"=="gendummies"  local mis = "stub"
	  if "`cmd'"=="geniimpute" local mis = "imputed"		// (these remaining commands do not have an m_prefixed outcome var)
	  if "`cmd'"=="genplace" local mis = "placed"			// (they use local `miss' to customize their var labels – see below)
	  if "`cmd'"=="genstacks" local mis = "stacked"
	  if "`cmd'"=="genyhats" local mis = "predicted"
	  
	} //endif `cmd'


	
	
	
  	
*pause on
pause cleanUp(2.1)
global errloc "cleanUp(2.1)"
pause off




										// (2.1)  NOW PREPARE STACKME VARS THAT RECORD MISSINGNESS FOR DIFFRENT CMDS
	
			 
	local ic = substr("`cmd'",4,1)							// Identifying char(s) used to distinguish interims produced by each `cmd'P
	if "`cmd'"=="gendummies" | "`cmd'"=="genmeanstats"  local ic = substr("`cmd'",4,2) 
	
	foreach ic2 in dd ii yd yi du  {						// Cycle thru `ic2's for all vars for which missingness is monitored

	  foreach SMvar in `ic2'misPlugCount SM`ic2'misCount SM { // Cycle thru the two summary measures for current command
															 // (using identirying char(s) (`ic') to differentiate variables)
															 
	    if "`ic2'"!="dd" & "`ic2'"!="ii" & "`SMvar'"=="SM`ic2'misPlugCount" continue, break // Only have misPlugCount for gendi & genii
															 // "d" covers both multivariate yhat and gendist outcomes
	    if "`SMvar'"=="SM`ic2'misCount"  {					 
			local txt = "original"							 // Set text to be included in var label for input var
	    }
	    else {												 // else set text for outcome var
			if "`ic2'"=="dd" local txt = "mean-plugged"		 // (i.e. mean-plugged, imputed or y-hatted)
			if "`ic2'"=="ii" local txt = "imputed"
			
/*			if "`ic2'"=="yd"  local txt = "Multivariate y-hat depvar"
			if "`ic2'"=="yi"  local txt = "Bivariate y-hat indep"
			if "`ic2'"=="du" local txt = "dummy"		 	 // (will overwrite any txt established when "d" was matched)
			if "`cmd'"=="genmeanstats" local txt = "stat" */ // COMMENTED OUT TO SIMPLIFY CODE
	    }
		
	    capture confirm variable `SMvar'					 // See if variable exists from previous occurrence of same cmd
		
	    if _rc==0  {										 // If that var already exists			(THIS ALREADY DONE EARLIER?)		***
	   
		  if "`SMvar'"=="SM`ic2'misPlugCount"  {				 // If this is first SMvar, see if 2nd also exists..
			capture confirm variable SM`ic'misCount
			if _rc==0  {								 	 // If so, store both variables in SMvar
			  local SMvar = "SM`ic2'misCount SM`ic2'misPlugCount"
			}		 		 							 	 // Else SMvar is just one variable (first or second in foreach list above)
		  }
		  else  local SMvar = "SM`ic2'misCount"			 	 // Else this is the second (and only) SMvar
		  capture confirm variable SM`ic2'misCount			 // If SM`ic'misCount exists and both are optioned then both exist
		  if _rc==0  {
			display as error "`SMvar' already exist(s); replace?{txt}"
*					          12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure ///
			  "`SMvar' already exist(s) (left by earlier `cmd' command); replace?"
			if _rc  {
			  errexit, msg("Lacking permission to drop `SMvar'") 
			  exit 										  	  // _rc was non-zero so user is not 'OK'n with dropping this/ese
			}												  
			drop `SMvar'									  // Else drop the left-over variable(s)
			
		  } //endif _rc==0									  // If did not exit above, process the variable established
		
		  else  {											  // Else SMvars do not already exist
					
		    if "`SMvar'"=="SM`ic'misCount"  {
			   local varnames = "`non2missing'"			  	  // Assign appropriate list of vars to be assessed for missingness
			   local lbl = "N of missing values for `txt'"
		    }												  // (misCount gets original missingness count – generally also outcm)
		    else  {
			  local varnames = "`vars'"				  	  	  // Else misPlugCount gets count for outcome missingness – if diffrnt
			  local lbl = "N of missing values for `SMvar'"   // (`tempnames' come from 'getoutcmnames', called at start of 10.1)
		    } //endelse
			
*		    ****************************
		    quietly egen `SMvar' = rowmiss(`interims')		  // Count of missing values for all unique vars
*		    ****************************
		
		    local nvars : list sizeof vars
		    local first = word("`varnames'",1)
		    local last = word("`varnames'",`nvars')
			
		    if "`first'"=="`last'"  {						  	  // If only one outcome var..
*			  ********************	
			  if word("`txt'",-1)!="stat"  {					  // If last word of label is NOT "stat"
			    capture label var `SMvar' "`lbl' var (`first')"
			  }											  	  // Else the var being labeled holds a stat measure
			  else  capture label var `SMvar' "`lbl' stat measure (`first')""

*			  ********************
			} //endif
		
			else {											  // More than one variable was included in 'egen'
*				****************
				if word("`txt'",-1)!="stat"  {
					capture label var `SMvar' "`lbl' vars (`first'..`last')"
				}
				else  capture label var `SMvar' "`lbl' stat measures (`first'..`last')""
*				****************

			} //endelse
					
			if "`SMvar'"=="SM`ic'misPlugCount" continue, break // Break out of SMv loop if both SMvars have been processed
															   // (or one var that was misPlugCount var)
		  } //endelse _rc==0
		  
	    } //endif _rc==0
		
	  } //next `SMvar'
		
	} //next `ic2'

	
	if `limitdiag' noisily display " "						  // Display a blank line to terminate per context diagnostics

															  // genmeanstats OUTCOME VARS WILL BE LABELED AT END OF codeblk 4

  
	
	
	

pause cleanUp(3)
global errloc "cleanUp(3)"




										// (3) Round/bound outcomes if optioned (again applies to all varlists)
												  
	
	if "`round'"!=""	 {									// If 'round' was optioned..
	   
		if `limitdiag'  noisily display "Rounding outcome variables as optioned"

		foreach var  of  local non2missing  {				// Cycle thru all outcome vars for all varlists (not yet prefixed)
	   
			if strpos("`skipvars'","`var'") continue		// Skip any that are all missing in all contexts

			qui sum `var'
			local max = r(max)
				
			if "`cmd'"=="gendist" | ("`cmd'"=="genyhats" & "`multivariate'"!="")  {
			   if substr("`var'",1,2)=="d_"  {						   // (DK WHY WE CHECK FOR THIS)									***
				  qui replace `var' = round(`var', .1) if `max'<=1 	   // If this was a gendist or multivariate genyhats command
				  qui replace `var' = round(`var') if `max'>1 &`max'<. // There will be only one pass through the foreach loop
			   }													   // ('cos the varlist will only contain the depvar)
			}

			if `prx'  {									 	// If proximities were optioned (`prx' is set above by a gendist option)
			   if substr("`var'",1,2)=="x_"  {				// (DK WHY WE CHECK FOR THIS												***
				  qui replace `var' = round(`var', .1) if `max'<=1
				  qui replace `var' = round(`var') if `max'>1 & `max'<.
			   }
			}
															// If max value of var is >1, round to nearest integer
			if "`cmd'"=="geniimpute" | ("`cmd'"=="genyhats" & "`multivariate'"=="")  {
			   if substr("`var'",1,2)=="i_"  {				// (DK WHY WE CHECK FOR THIS												***
				  qui replace `var' = round(`var', .1) if `max'<=1
				  qui replace `var' = round(`var') if `max'>1 & `max'<.
			   }
			}

			if "`cmd'"=="genyhats"&"`multivariate'"=="" { 	// If this was a bivariate genyhats command
			   if substr("`var'",1,2)=="y_"  {				// (DK WHY WE CHECK FOR THIS												***
				  qui replace `var' = round(`var', .1) if `max'<=1
				  qui replace `var' = round(`var') if `max'>1 & `max'<.
			   }											 // (there will be multiple passes thru the varlist, one for each indep)
			}
				
		} //next `var'
			  
	
	} //endif 'round'   			
	  
	  
	if "`bound'"!="" | "`minmax'"!=""  {					// SHOULD CHECK EARLY IN WRAPPER THAT DON'T HAVE BOTH						***
	  	
		if "`minmax'"!="" {
		 	local minval = word("`minmax'",1)
			local maxval = word("`minmax'",2)
		}
	  	if `limitdiag'  noisily display "Bounding outcome variables (limiting outcome value ranges) as optioned"

			foreach var  of  local non2missing  {			// Cycle thru all outcome vars for all varlists
	   
			   if strpos("`skipvars'","`var'") continue		// Skip any that are all missing in all contexts

			   if "`bound'"!=""  {							// If bounded values were optioned, get min & max of var
				  qui sum `var'
				  local minval = r(min)
				  local maxval = r(max)
			   }
			   if `minval'>`var' & `minval'<. qui replace `var' = `minval'
			   else  {
			   	  if `maxval'<`var' qui replace `var' = `maxval'
			   }
			   
			} //next `var'
			
	} //endif `bound' | `minmax'
		


  	
		

*pause on
pause cleanUp(4)
global errloc "cleanUp(4)"

pause off
											// (4)	This is where `ic'-prefixed variables are renamed to include respective cmd prefix 
											//		chars and genmeanstats outcome vars are labeled (othr vars were labled in blks 1-2). 

											// ***************************************************************************************
											// Prefixes cumulate as variables are augmented with dummy-variable replacements, distan-
											// ces, imputed values and y-hats; each command prepending additional prefixes to variable 
											// names. Note that variables that are deemed outcomes from each command may themselves have 
											// prefixes that define the provenance of each stackMe-generated variable, these should
											// not be changed without careful thought regarding alternative means for keeping track of
											// variable provenance (variable characteristics NOW PROVIDE A MEANS FOR DOING SO).
											// (WE HAVE PLANS FOR AN 'origin' UTILITY THAT WLD PUT FULL PROVENNCE INTO OUTCM VAR LABELS)
											// ****************************************************************************************

											
	local i = 0												   // Index keeps position in `prfxlist' in sync with position in `outcomes'

	foreach out of local outcmnames  {						   // `outcmnames' is a revision of `outcmnames' reconstucted in 'cleanup'(1)
		
		local i = `i' + 1 
		local pfx = word("`spfxlst'",`i')					   // Get prefix for this variable (saved in wrapper(3))
		if "`cmd'"=="genmeanstats"  local pfx = word("`genmeprfx'",`i')  
		if "`cmd'"=="gendist" & "`pfx'"=="x"  {
		   if "`proximities'"==""  continue  				   // Continue with next `oname' if `pfx=="x"' but proximities not optioned
		}													   // THERE SHOULD BE A BETTER LOCATION FOR THIS CHECK						***
		local iname = word("`inputnames'",`i')
		if strpos("`skipvars'","`pfx'`iname'")  continue	   // If var with this name has no observations, skip to next var
		local iname = word("`interims'",`i')				   // Put `cmd'P-generated version into `iname' (saved in cleanup(1.1))
		if "`iname'"=="`out'"  continue  	   				   // Don't rename if `oname' is same as `pfx'_`iname'
		
		capture confirm variable `out'					   
		if _rc==0  drop `out'								   // SOMEHOW A PREVIOUS `oname' CAN STILL EXIST (SHOULD REPORT AS ERROR)	***	
									
*			****************************					   // `oname' already has the needed intricately-constructed outcome prefix
			rename `iname' `out'							   // `out' is a revision of `outcmname' reconstucted in 'cleanup'(1))
*			****************************					   // `iname' is the varname that, in this case, may need a prefix added
		
		char define `out'[origvar] `iname'				   	   // Record origin of outcome var in terms of input varname
		local shortcmd = substr("`cmd'",1,5)				   // Produce a short-form command name (first 5 characters)
		char define `out'[origcmd] `shortcmd'				   // Store orign of outcome var in terms of cmd (used in cdblk cleanup 1.1)
		
	} //next oname

	
															// HERE RENAME VARS W QUASI-TEMPORARY ___(triple underline) PREFIXES
															// SINCE NAME CONFLCTS HAVE NOW BEEN RESOLVD
	if "`namechange'" !=""	{								// If, before merging with 'origdta' we changed the names of certain vars
															// (done in subprogram 'getprfxdvars'<-'wrapper to avoid merge conflicts)
		foreach var  of  local namechange  {				// Here we undo those name changes
		
		   local v = "`var'"
															
		   capture confirm variable `var'					// DK WHY WE NEED THIS CHECK?												***
		   if _rc ==0  {									// If return code indicates this is an existing variable

															// Quasi-temporary ("___" prefix) permitted co-existence or renamed vars
			  local temp = substr("`var'",4,.)				//  with those that previously had that name

*			  *******************
			  rename `var' `temp'							// Rename the quasi-temp var to have the same suffix but no "___" prefx
*			  *******************

		   } //endif _rc  									// (GLOBAL 'namechange' MAY (REDUNDANTLY) STILL HOLD NAMES OF RENAMEDVARS)	*** 
															// NEW VERSION'S LIST OF QUASI-TEMPORARY, IS IDENTIFIED BY "___" PREFIX
		} //next var
		
    } // endif namechange 
	
	

	if "`skipvars'"!="" & "`skipvars'"!="."  {				// If there were any vars with no observations for any context..
		
		local skipvars = strtrim(stritrim("`skipvars'"))
		local skipvars : list uniq skipvars					// Remove duplicates from `skipvars'

		dispLine "For variables listed here, no valid observations were found in any context: `skipvars'; drop these vars?"
*				  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		local rmsg = "`r(msg)'"
		
		capture window stopbox rusure "`rmsg'"
		if _rc  {
			errexit "Lacking permission to delete these variables, they will be kept"
		}
		else  drop `skipvars'

	} //endif `skipvars'
  
    local skipcapture = "skip"							 	// In case there is a trailing non-zero return code
															// (his cmd executes if there was no error between the capture braces
	
*  *************											 *************************************************************************
  } //endcapture											 // Close brace enclosing code, back to top, whose errors will be captured
*  *************											 // (any error found there will cause execution to skip to following code)
*														  	 *************************************************************************
	
	
	
  if _rc & "`skipcapture'"==""  {
  	
	errexit "Error in $errloc"
	
  }
  
  
  
end cleanUp
	

	
	
************************************************************************************************************************************




capture program drop dispLine					// Called from errexit and elsewhere (in lieu of calling errexit)

program define dispLine, rclass					//`msg' text is divided in two at ";" if any. What starts with ";" is appended to
												//  (abbreviated) text if `msg' does not fit in optioned # of lines (3 by default) 
												
args msg aserr maxlines							

												
global errloc "dispLine"

if "$busydots"!=""  noisily display " "			// If previous display ended with _continue, display a blank line

if "`maxlines'"==""  local maxlines = 3			// By default, display up to three 80-column lines (to change `maxlines', 2nd option
												//  must be "aserr" or some other non-empty string); use "aserr" string for 'display
												//  as error' – otherwise use, e.g. "noerr", if `maxlines' is to be optioned.
*****************
capture noisily  {								// Any error occurring before corresponding close brace will be captured
*****************								// (and processed after that close brace)
	
  gettoken msg last : msg, parse(";") 						// If `msg' contains ";", that and rest of `msg' will suffix (abbrv) txt
  local allmsg = "`msg'"
  															// (leaves `msg' shorn of terminal "last")
  if "`last'"!=""  local lenl = strlen("`last'")			// Length of suffix determines max length of final line to be displayed
  else local lenl = 0										// Make `lenl' =0 if there is no suffix
  local maxwidth = 80 - `lenl'								// `maxwidth' is max width of final line displayed, when suffix is added
  local maxwidnl = 81										// `maxwidnl' is max width of any non-final line (line with no suffix)
															// TAKE ACCOUNT OF THIS ADDITIONAL WIDTH AT LATER TIME; TOO DIFFICULT NOW	***
  local lnc = 1												// Initialize linecount of line being displayed
  
  while strlen("`msg'")>`maxwidth' {						// While 'msg' (including final `last' if any) extends beyond `maxwidth'
															// (need space for final "?" if any)
	local lastsp = strrpos(substr("`msg'",1,81)," ")		// Find last space in 81-char substring (note the two "r"s in `strrpos') 
															// (if there is a space at 81st char, that is fine)
	local line = substr("`msg'",1,`lastsp'-1)				// (`lastsp` could be 81, in which case we would have an 80-column line)
	if"`aserr'"=="aserr" noisily display "{err}`line'{txt}" // Display this line 'as error' if optioned (no `last' appended)
	else  noisily display "{txt}`line'"						// Else display it noisily (last line will be displayed after endwhile)
	
	local msg = substr("`msg'",`lastsp'+1, .)				// Trim from head of `msg' what was just displayed, plus final space
	if strlen("`msg'")<=(80-`lenl')  continue, break 		// If chars left to display are < available chars, break out of loop
															// Else see if additional lines can be displayed
	local lnc = `lnc' + 1									// Increment linecount for line that will be displayed next
	if `lnc'>=`maxlines' & strlen("`msg'") > 80-`lenl'  {	// If this count >= `maxlines' and > 80+ chars are left in `msg'+suffix
	   if substr("`msg'",-1,1)==" " local i = "-1"
	   local msg = substr("`msg'",1,(80-`lenl'-2`i'))+".."	// Trim rest of `msg' beyond what fits current ln; append ".."
	}														// If final char was a space, trim it off and add an extra dot
	else  {								   					// Else there are less than 80 chars left or more lines to display
	   if `lnc'<`maxlines'  continue						// More lines can be displayed, so continue with next while loop
	   else  { 												// Else there are less than `lenl'+1 chars left, so display last line
	      continue, break									// Break out of loop so msg will be displayed post-while
	   }
	} //endelse
	
  } //endwhile 'msg'>`maxwidth'
  
  
  
  if "`msg'"!=""  {											// If there are any characters left un-displayed (reached end of `msg')
 	if substr("`msg'",-1,1)==" "  local msg = substr("`msg'",1,strlen("`msg'")-1) // Trim off final char if it is blank 
	local dMs = "`msg'`last'"

	
	if "`aserr'"=="aserr" noisily display "{err}`dMs'{txt}" // Display final (or only) line +`last' as error if optioned
	else noisily display "{txt}`dMs'"						// Else display it noisily
  }
  
  
															// Now return the entire trimmed message for caller to optional use
															
  local maxchars = `maxlines' * 80							// Find max chars corresponding to optioned (or default) max lines
  
  if strlen("`allmsg'")>`maxchars'  {						// IF STRING IS TOO LONG ..
  	 local msg = strrtrim(substr("`allmsg'",1,`maxchars'))	// Trim any trailing blanks
	 local lastsp =strrpos(substr("`msg'",1,`maxchars')," ") // Find last space in `maxchars' substr (note the two "r"s in `strrpos') 
	 local msg = substr("`msg'",1,`lastsp'-1) + ".." + "; `last'"
  }	//endif													// Construct abbreviated `msg' to be returned
  
  else  {													// Else construct full message to be returned
	 if substr("`allmsg'",-1,1)!=" " local allmsg = "`allmsg' " // Add space at end of `line', if needed
  	 local msg = "`allmsg'`last'"
  }	
  
  return local msg "`msg'"
  
  
  local skipcapture = "skip"								// If execution passes this point, no error was captured

  
  
************** 
} //endcapture
**************



if _rc & "`skipcapture'"==""  {
  errexit "Error in $errloc"
  exit
}
														


end dispLine




*****************************************************************************************************************************************



capture program drop errexit					// Called from everywhere

program define errexit							// THIS ERROR-REPORTING SUBPROGRAM WAS DESIGNED AS TWO SUBPROGRAMS IN ONE. IF subprogname
												// IS FOLLOWED BY COMMA, errexit PARSES THE OPTIONS; ELSE LOOKS FOR 1 OR 2 ARGUMENTS.
												// FIRST ARG OR OPT IS ALWAYS MSG TO BE SENT TO STOPBOX. IF IT COMES AS AN ARG IT IS
												// ALSO DISPLAYED IN RESULTS WINDOW AND, IF FOLLOWED BY ANOTHER STRING, 2ND STRING IS 
												// PROCESSED AS A STATA ERROR (in two different ways, depending on type).
												//   IF STRINGS COME AS OPTIONS, errexit EXPECTS PRIOR DISPLAY BY CODEBLK THAT DIAGNOSED
												// THE ERROR AND, IF $exit==1, RESTORES ORIGINAL DATA IN $origdta PRIOR TO EXITING
												// (complexity is due to need to handle legacy code that used just two arguments)
												// NOTE THAT, IF 'msg' IS "Error exit" THE LOCATION OF THE ERROR IS ADDED, FROM $errloc
												// (check those names in case they match already extant varnames)

* DON'T SET $errloc								// (We want to retain location from which 'errexit' was called)


if "$SMreport"!=""  exit 1						// If the error was previously reported then the call on this program was redundant
												// (exit 1 invokes the same subprogram as pressing the Break key)
if "$exit"==""  global exit = 0					// If $exit is empty that will be because it has not yet been set

if "$SMrc"==""  global SMrc = 0					// If $SMrc is empty give it a return code of 0
if $SMrc==0  global SMrc = _rc					// If $SMrc already holds an error code, leave it unchanged
												// (else give it the current value of _rc)

	
********
capture noisily {								// Open capture brace marks start of codeblock within which errors will be captured
********

    if "`1'"==","  {							// If what was sent to 'errexit' starts with a comma, errexit handles all possibilities
												// NOTE: 'msg' always sent to stopbox; to results only if came as arg or with 'display'
												// ($origdta will be restored if $exit==1, for both 'arg' and 'option' versions)
*	   *********************
	   syntax , [ MSG(string) rc(string) DISplay *]
*	   *********************

	   if "`display'"!="" scalar DISPLAY = "display"
	   else scalar DISPLAY = ""					// Uninitialized scalar is not empty, like an unitialized macro, and we want this empty
    }											// (optional `rc' is Stata return code – RC – or string that caused the error)
	
	else  {										// Else there is no comma, so up to two arguments were sent as 'arg's
	   args msg rc								// First arg is `msg' to display; 2nd is optional Stata return code, if numeric
	   scalar DISPLAY = "display"				// (there is no comma, so 'msg' argument is for stopbox AND for Results window)
	}											//  Optional 'rc' is either RC or holds command-line string responsible for the error
	
	if "`rc'"!=""  global SMrc = "`rc'"			// Put in quotes because it may be a string
	
*	***************
	capture restore								// Must restore any preserved data before exit
*	***************
	

	if $exit==1 {								// IF (RESTORED) DATA HAS BEEN MODIFIED BEFORE ERROR, also 'use' the original dataset
	   capture quietly use $origdta, clear 		// Here restore 'origdta' dataset (provided not already done so)
	   capture erase $origdta 					// (and erase the tempfile in which it was held, if any)
	} //endif	
	
												// SINCE WE EXIT, WE MUST DROP ALL globals, WHICH YIELDS A TRICKY PROBLEM addressed...
	scalar SMrc = "$SMrc"						// Save in a scalar the global copy of a non-zero error code or command
	scalar SMmsg = "`msg'"						// Save in a scalar the 'msg' argument or option
	scalar ERRLOC = "$errloc"					// Ditto for $errloc
	scalar EXIT = "$exit"						// Ditto for $exit
	scalar MULTIVARLST = "$multivarlst"			// Ditto for $multivarlst
	capture confirm existence $limitdiag
	if _rc global limitdiag = -1				// If $limitdiag was not yet initialized, put it into its default state
	scalar LIMITDIAG = "$limitdiag" 			// And for $limitdiag
	macro drop _all								// Clear all macros before exit (evidently including all of the above)
	capture drop ___*							// Drop all quasi-temporary vars (vars with names starting "___")
												// (note that scalars are not macros so they are not dropped by above command)
	global SMrc = SMrc							// Get $SMrc back from its scalar copy
	local msg = SMmsg							// Governs way in whicn msgs are displayed
	global errloc = ERRLOC						// $errloc is needed by caller program, re-entered after wrapper 'end' command
	global exit = EXIT							// Ditto for $exit
	global multivarlst = MULTIVARLST			// Ditto for $multivarlst	
	global limitdiag = LIMITDIAG				// And for $limitdiag

	global SMreport = "reported"				// Flag, set here to survive above code, averts duplcte report from calling prog
	
		
		
	if "$SMrc"!=""  {							// IF ERREXIT WAS CALLED BY A stackMe PROGRAM WITH KNOWLEDGE OF A STATA ERROR..
	   capture confirm number $SMrc 			// See if it was a numeric return code
	   if _rc  {								// Not numeric so "$SMrc" holds the command line that caused the error
	   
		  if "`msg'"==""  local msg = "Stata reports likely data error in $errloc"  
		  if DISPLAY !=""  display as error "``msg'{txt}" // (DISPLAY is a scalar flag, set on entry to this SUBprogram)
		  
		  if strpos("`msg'","blue")==0 window stopbox note "`msg'; will exit on 'OK'" // Version if no "return code" in 'msg'
		  else window stopbox note "`loc2'`msg' – click on blue return code for details; will exit on 'OK'" // Else this version
		  "$SMrc"								// Invoke the command line that caused the error, so Stata reports the RC
	   } 
	
	   else  {									// Else $SMrc is numeric so likely a captured return code
							
		  if "`msg'"==""  {						// IF `msg' IS EMPTY THEN THERE IS ONLY A RETURN CODE
		  	 noisily display "Likely program error `rc' in $errloc – click blue return code for details" 
*		   							   12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			 window stopbox note "Likely program error `rc' in $errloc – click blue return code for details"
			 exit
		  } //endif `msg'
		  else  {								// Else there was a message with the return code
			 dispLine "`msg'; will exit on OK" "aserr" 1 // limit to 1 line of text displayed in output window
			 window stopbox note "`msg'; will exit on 'OK'"       // No limit for stopbox display
			 exit
		  }
		    
		} //endelse  $SMrc
		
	} //endif $SMrc
	
		  
	if DISPLAY !=""  {							// IF DISPLAY SCALAR FLAG WAS SET NON-EMPTY earlier in program)
	
	   if "`msg'"!=""  {	
		  if strpos("`msg'","click")  { 		// If 'msg' contains a 'click on blue..' clause
			 display as error "`msg'"
			 window stopbox note "`msg'; will exit on 'OK'" 
			 exit				  				// Above will be displayed if there was no "return code" in 'msg'			***
		  }
												// Else this is a standard errorexit with two variants ..
												// If `msg' is non-empty, add "in $errloc" and "will exit on 'OK' as needed
		  if strpos("`msg'","$errloc")==0  local msg = "`msg' (in $errloc)"	    // Add " (in $errloc)" if not already there
		  if strpos("`msg'","permission to") & ! strpos("`msg'","will exit")  { // Add "will exit" if ditto
			 dispLine "`msg'; will exit on 'OK'" "aserr" 1	// limit to 1 line of text displayed in output window
			 window stopbox note "`msg'; will exit on 'OK'" // No limit for stopbox display
			 exit
		  } //endif
		  else  {
		  	 dispLine "`msg'"
			 window stopbox note "`r(err)'"
			 exit
		  }
		  
	   } //endif `msg'
	   
	} //endif DISPLAY	
	
/*												// FOLLOWING CODE MAY COME IN HANDY BUT SEEMS NO LONGER RELEVANT		  
	else  {										// Else $SMrc is empty
	   if DISPLAY !=""  {						// DISPLAY is a scalar; it shows 'display' was implied or optd earlier in ['errexit']
	     if strlen("`loc'`msg'")>80  {			// If total length (including any for `loc') >80...
		   dispLine "`loc'`msg'" "aserr"		// Use more that one line, if needed, to add "In $errloc"
		 }
		 else noisily display as error "`loc'`msg'"
		 window stopbox note "`loc2'`msg'; will exit on next 'OK'"
	   }
	}	
*/

	scalar drop SMmsg FILENAME DIRPATH ERRLOC EXIT MULTIVARLST LIMITDIAG 
												// Drop scalars used to secure above macros (not including scalar display)
	exit										// Exit 0 will be turned into exit 1 (a BREAK exit) for final exit
	
	local skipcapture = "skip"					// Flag to skip capture code if that code was entered from here
												// REDUNDANT SINCE EXECUTION CANNOT GET BEYOND HERE UNLESS ERR WAS CAPTURED?

***************
} //endcapture									// End of codeblock within which errors will be captured
***************




if  _rc & "`skipcapture'"==""  {				// If entered this block without 'skipcapture' being set, 2 lines up, ..
												// (that means the error occurred in the captured part of above code)
	noisily display as error "'errexit' diagnosed an error within itself – click blue RC for details{txt}"
*					          12345678901234567890123456789012345678901234567890123456789012345678901234567890
	window stopbox note "'errexit' diagnosed an error within itself – click blue return code for details"
	exit _rc
}

	
end errexit





********************************************************************************************************************************





capture program drop getoutcmnames							// Called from 'getprfxdvars' (next subprogram below this one)
															// (on return to which, local inputnames, outcmnames, spfxlst become globals)

program define getoutcmnames, rclass						// Returns lists of input and corresponding outcome & strprfx names
															// (outcome names already fully prefixed; others combine to make outcm names)

syntax [varlist(default=none)] [, $mask APRefix(str) DPRefix(str) IPRefix(str) MPRefix(str) PPRefix(str) XPRefix(str) DUPrefix(str)		   ///
								  NPRefix(str) MEAnprefix(str) SDPrefix(str) MINprefix(str) MAXprefix(str) SKEwprefix(str) KURtprefix(str) ///
								  SUMprefix SWPrefix(str) MEDianprefix(str) MODeprefix(str) PROximities(string) MULtivariate(string)	   ///
								  NPRefix MEAnprefix SDPrefix MINprefix MAXprefix SKEwprefix KURtprefix SUMprefix SWPrefix				   ///
								  MEDianprefix MODeprefix * ]
								  




pause getoutcm(1)
global errloc = "getoutcm(1)"

* ****************
  capture noisily {											// Open braces enclose code within which any error will be captured
* ****************											// (and processed after the matching close braces at end of program)

    local cmd = "$cmd"
	
	local gendu = 0
	if "`cmd'"=="gendummies"  local gendu = 1				// CLUGE TO CORRECT INCOMPREHENSIBLE ERROR IN if "gendummies"=="gendummies" 														***
	
	local inputnames  =  ""									// Local that will be returned to caller w list of inputnames
	local outcmnames  =  ""									// Ditto w list of outcome names
	local spfxlst = ""										// Ditto w list of full prefix that distinguishes outcome from input name
	local stubnames = ""									// (either default or with user-optioned optprefix and/or aprefix)
	
	
	
											// (1) GET LIST OF PREFIX-NAMES FOR CURRENT `cmd' 
											//	   (`cmd' will generate 1 var for each optname)
											
												
	if "`cmd'"=="gendist"  local optnames     = "dprefix mprefix pprefix" 			   // (aprefix is implemented in codeblk 1.2)
	if "`cmd'"=="gendist" & "`proximities'"!=""  local optnames = "`optnames' xprefix" // Add xprefix if "proximities" were optd
	if "`cmd'"=="gendummies"  local optnames  = "duprefix"							   
	if "`cmd'"=="geniimpute" local optnames   = "iprefix mprefix"
	if "`cmd'"=="genmeanstats" local optnames = "nprefix meanprefix sdprefix minprefix maxprefix skewprefix kurtprefix sumprefix " ///
											  + "swprefix medianprefix modeprefix" 	   // (same order as in 'genyhatsP')
	if "`cmd'"=="genplace"  local optnames    = "iprefix mprefix pprefix" 
	if "`cmd'"=="genyhats" local optnames     = "iprefix" 	// `dprefix' will be substituted if this varlist has a `yh@' prefix
															// Above are the naming options that may be user-invoked for each cmd	
	
*	scalar OPTNAMES = "dprefix iprefix mprefix pprefix xprefix" 
															// These are all the opnames used by one cmd or another, except 'genme'
	
	
	
	
	
	
											// (1.1) GET IDENTIFYING CHARACTER(S) FOR CURRENT CMD (i.c. – eg "d" for gendist)
											
											
	local ic = substr("`cmd'",4,1)			
	
	if `gendu' | "`cmd'"=="genmeanstats"  {					// For most cmds the `ic' is the 1st character following "gen"
															// (this line of code produced the incomprehensible error mentioned above)
	   local ic = substr("`cmd'",4,2)						// But 'gendummies' and 'genmeanstats' have 2-char 'ic's	
	}														// (further honing of 'genme' `ic's will occur when cycling thru `optname's)
	
	if "`aprefix'"=="_"  local aprefix = ""					// If a previous subprogram already pre-processed `aprefix', empty it
	
	local apfx = "_" 										// Create default `aprefix'	
	if "`aprefix'"!="" local apfx = "`aprefix'"				// By default, `aprefix' inserts a "_" after identirying char(s)

	
	
	
	
pause getoutcm(2)
global errloc = "getoutcm(2)"
		
		
											// (2) GET VARIABLES, PREFIXVARS, STUBNAMES AND STRPREFIXES FOR THIS VARLIST
											
											
	local multivariate = MULTIVARIATE						// By default take the user-optioned 'genyhats' multivariate flag
											
	local statprfx = STATPRFX								// NOTE that 'genmeanstats' 'strprfx's were saved as scalars at wrapper(3)
	local statlen = wordcount("`statprfx'")					// (only one varlist is allowed with 'genme' `cos never imagined more)
	local statrtrn = STATRTRN								// (same length as `statprfx')
		
	
	local nvarlsts = NVARLSTS								// get N of varlists from scalar NVARLSTS set in wrapper(2.1) 
	
	forvalues nvl = 1/`nvarlsts'  {							// Cycle thru all varlists (from scalar NVARLSTS in codeblk 10)
															
	  local dvar = ""										// By default this is not a `multivariate' yhat
									
	  local varlist = VARLISTS`nvl'							// Same scalar used in codblk cleanup(10) lists varnmes for each varlst
	  local prfxvars = PRFXVARS`nvl'						// Retrieve any prefixes that are varnames (THESE DO NOT AFFECT VARNAMES)
	  local stubnames = VARSTUBS`nvl'						// Ditto for stubnames used by 'gendummies' (can be empty or missing)
	  local strprfx = PRFXSTRS`nvl'							// And any string prefix to those var prefixes (1 per listof `prfxvars')
	  if "`strprfx'"=="."  local strprfx = ""				// (so it is duplicated as many times in `strprfx' as there are outcomes)
	  local gotat = GOTAT`nvl'
	  
	  if MULTIVARIATE`nvl'!=""  local multivariate = MULTIVARIATE`nvl' // User-optioned version (above) is overridden by `yh@' prefix
	  if  "`multivariate'"!=""  local dvar = "`depvarname'"	// Multivariate genyhats generates optioned depvar by default
	  if "`gotat'"!=""  local dvar = "`gotat'"				// Prefix to multivariate varlist overrides optioned depvar, if any
															// (only one depvar for multivariate yhat analyses)
	  if "`dvar'"!=""  {
	  	 local varlist = "`dvar'"							// If a multivarte 'genyh' was opted or prfxd then `dvar' is only outcome
		 local optnames = "dprefix"							// (and the only `optname' is `dprefix')
	  }
	  
	  local nv = 0											// Variable # within varlist
	  
	  
	  foreach v  of  local varlist  {						// Cycle thru all outcome vars for each varlist (inputs, for multiv genyh)
	  
		 local nv = `nv' + 1								// Increment position in varlist to synchronize w prfxvars & other lists
	   
		 foreach opt  of  local optnames  {					// Go thru optionable string prefixes for current cmd (usng v1 naming)
	
			local spfx = substr("`opt'",1,1)				// For most commands, interim vars generated by `cmd'P have this prefix
															// ('opnames' names are specific to the current command – see (1) above)																  
			if "`cmd'"=="gendummies"  local spfx = "du"		// For 'gendu', interim prefix is same as default outcome prefix
			
			if "`cmd'"=="genmeanstats" {
			   local spfx = substr("`opt'",1,2)				// For 'genme' use 1st 2 chars of cmd's current optname as interim prefix
			   if "`opt'"=="medianprefix"  {				// "medianprefix" has same 1st 2 chars as "meanprefix"', so disambiguate
				  local spfx = "md"							// (STATA MISBEHAVES IF WE USE 'if' AND 'else' ON SUCCESSIVE LINES)			***
			   }											// Poor design requires repeat of 'genmeanstats' parsing done at wrapper(3)
			   if "`spfx'"=="np"  local spfx = "n"			// Need this tweak to handle single character "n" option for 'genme'
															// (short for "n of observations – the "p" was next char of optn `nprefix')
			} //endif `cmd'=='gendummies'					// ('gendu' and 'genme' make no use of `ic', using `spfx' instead
			
			if strpos("gendummies genmeanstats","`cmd'") {	// if `cmd' is 'gendu' or 'genme'..
			   
			   local opfx = "`spfx'"						// The outcome prefix is same as interim prefix, unless ``opt'' was optioned
															// (see if ``opt'', below)
			}
															// Else, for other commands,..
			else  local opfx = "`ic'`spfx'"					// outcm varname prefixes are constructd by prefixng interim prefix with `ic'
														
														
			if "``opt''"!=""  {								// If this optname, specific to each `cmd', was optioned...
															// (signalled by non-empty ``opt'', which points to what was optioned)
				local opfx = "``opt''"						// Use double-quotes to access the string that the user supplied
															// (this string will replace the default `ic' prefixing an outcome varname)													
				if substr("`opfx'",-1,1)=="_"  local opfx = substr("`opfx'",1,strlen("`opfx'")-1) // Remove trailing "_" if any
															// (would duplicate the "_" provided by a default `aprefix')				
			} //endif ``opt''								// If not empty will be used in preference to `spfx' in next codeblk
															// (else, because empty, will not contribute to outcome varname)
			  
															// ALL OF THE ABOVE CAN BE OVERRIDEN BY A STRING PREFIX TO A PREFIXVAR
			if "`strprfx'"!=""  local opfx = "`strprfx'"	// (`strprfx' can prefx each varlst and overrides ``opt'' even if not empty)
			if "`opfx'"=="yh"  local opfx = "yd"			// If the parsng symbol was "@", it can still have a strprfx – "yh" or othr
	
	
	

	
pause getoutcm(3)
global errloc = "getoutcm(3)"


											// (3) BELOW CREATE AS MANY OUTCOME VARNAMES AS REQUIRED BY N OF OPTNAMES FOR THIS CMD,
											//	   (OR BY N OF VALUES FOR EACH STUB IF OUTCOME IS A SET OF DUMMY VARIABLES)
		
				
															 
			if !`gendu'  {						 			 // ******************** (`gendu' WAS SET IN CODEBLK 0 AS BUG-FIX)
			  if "`cmd'"!="genmeanstats" {					 // IN THE GENERAL CASE, store `outcmnames', etc., for r-return to caller
															 // ********************
															 // THE N OF OUTCOME VARS IS ONE PER OPTION, NO MATTER WHETHER USER-OPTD
				****************   *****************		 // Use input prefix (from start of `opt' loop) for `v'
				local inputnames = "`inputnames' `v'"		 // Caller may need unadorned varname
				local spfxlst = "`spfxlst' `spfx'"		 	 // Provides the prefix adornment to get a `cmd'P-generated interim varname
				local outcmnames = "`outcmnames' `opfx'`apfx'`v'" // 'opfx' is `ic', unless overriden; `spfx' is optionable prefix
				local varlistno = "`varlistno' `nvl'"		 // Links outcome var to its origin in the varlist typed by user
*				****************   *****************		 // For most commands the `opfx' starts with `ic' unless overridden	
															 // (if aprefix was not optnd, outcome prefix is "`ic'_" – see above)

			  } //endif `cmd'!="gendummies"&!"genmeanstata"	 // END OF PROCESSING FOR COMMANDS IN GENERAL (EXCEPTING 'gendu' & 'genme')
		    } //endif	
				
			
			
			
			
			
															// **************************
															// IF COMMAND IS 'gendummies' (can have several values == several outcomes)
			if "`cmd'"=="gendummies"  {						// **************************

				local name = "`v'"							 // FOR 'gendu', N OF OUTCOME VARS IS ONE FOR EACH VALUE OF EACH INPUT VAR
															 // (`name' needed to provide for stubs either derivd from input or optiond)
				if "`stubname'"!="" local name="`stubname'"  // Optiond stubname replaces default stubname (derived from input varname)
				if "`stubnames'"!=""  {						 // If prefix `stubnames' not empty they take priority over optiond stubname
				  local name = word("`stubnames'",`nv')	 	 // Trumped by a stubname corresponding to each input variable
				}											 // (using `name' in lieu of `v' avoids possibilty of schlocking `v')
				local tlen = strlen("`name'")				 // Get length of varname pointed to by `v' or `stubname'
															
				if real(substr("`name'",`tlen'-1,1))!=. { 	 // If last char of `name' is numeric (conversion to real is NOT missng)..
				   errexit "Apparent user error: a dummy input stub should NOT end with a numeric character"
*						    12345678901234567890123456789012345678901234567890123456789012345678901234567890 
				   exit
				} //endif
			
*				rename `v'#  `ic'`o'_`v'#			 		// THIS SYNTAX DOES NOT WORK, DESPITE WHAT IT SAYS IN  "help rename group"	***

				if "`duprefix'"!="" local spfx="`duprefix'" // (overridden if `duprefix' was user-optioned)
															// Save in list of varname prefixes used to diagnose varname conflicts
				quietly levelsof `v', local(V)				// MUST GET VALUES OF VARIABLE, NOT STUB!		  
				  
				foreach val of local V  {				   	// For gendu we get as many outcome names as the var had values
															// (there is only one quasi-optname for gendummies)
				   capture confirm number `val' 			// Error if `val' is NOT numeric 
				   if _rc {
			          errexit "Apparent user error: a dummy outcome varname should have a numeric suffix"
*						       12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			           exit
				   }
				   	
*				   ************************   ************	// Caller will need an unadorned varname
				   local inputnames = "`inputnames' `v'" 	// `inputname' gets the varname that the user typed
				   local spfxlst = "`spfxlst' `spfx'"		// 'spfx' is "du" by default, else user-optioned ``duprefix'' or `prfxvar'
				   local outcmnames = "`outcmnames' `opfx'`apfx'`name'`val'" // 'opfx' is "du" unless overridden; there is no `spfx'
				   local varlistno = "`varlistno' `nvl'"	// Links outcome var to its origin in the varlist typed by user
**				   ************************   ***********	// (`name' is unique to 'gendu', allowing `name'`val' to replace `v')
															// (also, as with 'genme', )
				} //next `val'
				
			} //endif "`cmd'"=="gendummies"				// END OF PROCESSING FOR COMMAND 'gendummies'
			  
			  
			  
			  
			  
			  
															// *****************************************************************
			if "`cmd'"=="genmeanstats"  {					// ELSE COMMAND IS 'genmeanstats' (can have several optnames )
															// ****************************	  (we are already in optname loop)
															
															// NOTE THAT 'genmeanstats' PREFIXES, ESTABLISHED BY OPTION 'stats'
															// AFTER 'wrapper'(3), DETERMINE WHICH `optnames', CURRENTLY BEING
															// CYCLED THRU & IDENTIFIED BY `spfx', WILL GOVERN THE OPTIONAL
															// RENAMING OF THE 'genmeanstats' OUTCOME VAR BY CHANGING ITS PREFIX.
															// ******************************************************************
				if strpos("$statprfx","`spfx'")==0 continue	// Continue with next option if this one not in list of optd stats
															// ($statprfx was established at wrapper(3))
				
				****************   ******************		// HERE THE NUMBER OF OUTCOME VARS IS THE NUMBER OF OPTIONED STATS
				local inputnames = "`inputnames' `v'"		// Caller may need unadorned varname
				local spfxlst = "`spfxlst' `spfx'"			// 'genmeanstats' uses `stat' as prefix for `cmd'P interim names
				local outcmnames = "`outcmnames' `opfx'`apfx'`v'" // `opfx' is statistic initials; there is no `spfx'
				local varlistno = "`varlistno' `nvl'"
*				****************   ******************


			} //endif `cmd'=="genmeanstats"					// END OF PROCESSING FOR COMMAND 'genmeanstats'
			 
			local spfx = ""									// Empty this in case next var has no user-optioned prefix
			
		 } //next `opt'
		  
	  } //next 'v'
	   
	} //next 'nvl'
	

*pause on

pause getoutcm(4)
global errloc = "getoutcm(4)"
		
pause off	
	
											// (4) CHECK FOR DUPLICATE OUTCOME NAMES AND DROP IF USER PERMITS
											
											
												
	local dups : list dups outcmnames						// 'list dups' returns list of names that are duplicates
	
	if "`dups'"!=""  {
		local dups : list uniq dups
		dispLine "Duplicate outcome varnames: `dups'; drop these?"
		local msg = r(msg)
		capture window stopbox rusure "`msg'"
		if _rc  {
			errexit "Lacking permission to drop duplicate outcome varnames"
			exit
		}
		foreach d of local dups  {
			local outcmnames = subinstr("`outcmnames'","`d'","",1)
		}
	} //endif
	

	
	foreach obj  in  inputnames spfxlst outcmnames  {
		local obj = strtrim(stritrim("`obj'"))				// Strip leading and internal excess blank(s) from each local list
	}										

	
	scalar OUTCMNAMES = "`outcmnames'"						// There are as many`outcmnames' as there are different outcome prfxs
	scalar INPUTNAMES	= "`inputnames'"					// There are as many`inputnames' as there are different outcome prfxs
	scalar PRFXNAMES	= "`prfxvars''"						// Ditto (CALLING THEM prfxvars IS UNFORTUNATE LEGACY NAMING CHOICE)		***
	scalar VARLISTNO = "`varlistno'"						// There are as many `varlistnos' as there were varlists
	scalar STUBNAMES = "`stubnames'"						// Same for the `gendummies' `stubnames' if STUBNAMES is not missing
	scalar OPTNAMES	= "`optnames'"							// Save having to initialize these again for this subprogram
	scalar SPFXLST = "`spfxlst'"							// ('genme' has the same multiplier in regard to stat names in $statlst)


	
	local skipcapture = "skip"								// If execution passes this point there were no coding errors above
	
		
*  *************	
  } //endcapture											// Close praces end codeblocks in which coding errors will be captured
*  *************
	
	
  if _rc & "`skipcapture'"==""  {							// If `skipcapture' is empty then a coding error was captured above
     errexit "Error in $errloc"
     exit
  }
													

end getoutcmnames




**************************************************************************************************************************************




capture program drop getprfxdvars							// Called from wrapper(5) with `optionsP' options-list


program define getprfxdvars									// Anticipate the names of outcome vars produced by current cmd
															// (check those names in case they match already extant varnames)
									
local errloc = "$errloc"
gettoken caller rest : errloc, parse( "(" )					// Set flag according to whether call was from wrapper or cleanup
if "`caller'" == "cleanup"  exit							// Go right back if call was from cleanup (SHOULD NOT MAKE THAT CALL)		***

local cmd = "$cmd"

	
											//****************************************************************************************
											// THIS SUBPROGRAM CHECKS WHETHER WHAT WILL BE OUTCOME VARNAMES ALREADY EXIST AND, IF NOT,
											// WHETHER CORRESPONDING `cmd'P-GENERATED `ivar's ALREADY EXIST. IF EITHER, CHECK IF USER 
											// ANTICIPATED THE NAME CLASH BY OPTIONING NEW PREFIX-STRINGS FOR THE VARS CONCERNED. BUT 
											// THIS LEAVES A TEMPORARY PROBLEM UNTIL RENAMING (WHICH IS THE LAST THING DONE). SO
											// CAPITALIZE FIRST CHAR OF OUTCOME PREFIX AND ACCUMULATE LIST OF SUCH TEMPORARY CHANGES 
											// IN GLOBAL namechange – A GLOBAL THAT GOVERNS RESTORATION OF ORIGINAL NAMES AFTER NEW 
											// OUTCOME ivars IN WORKING DATA HAVE BEEN RENAMED IN 'cleanup' TO ovars. BUT START WITH  
											// CHECK TO SEE IF ANY SUCH NAME-CHANGED VARS ACCIDENTALLY REMAIN BECAUSE OF ERROR EXIT.
											// (renamed to local namechange in 'cleanup).
											// VOCABULARY: `iname'/`oname' are text strings and ivar/ovar are vars with those names
											//			   [`cmd'P-generated] `ivar' is renamed to `ovar' by 'cleanup' before cmd exit
											//****************************************************************************************
pause getprfxdv(0)
global errloc "getprfxdv(0)"

											// (0) SET UP CONSTANTS NEEDED BY LATER CODEBLOCKS


* capture noisily {											// CLUGE PREVENTS 'UNRECOGNIZED COMMAND' ERROR AT close-'capture' BRACES
* *****************											/*// (not currently a problem, so commented out)*/
  capture noisily {											// (Syntax etc) errors in captured codeblks to up to matching close  
* *****************											//   brace will cause jump to command following that close brace


  	
*	*****************************	
	syntax [varlist], [ $mask * ] 							// Provide access to all current user-supplied options
*	*****************************							// (was called with `optionsP' option)


		
/*	if "$cmd"=="gendist"  	 local prfxlst = "d m p"		// Assign 1-char (second) char for other cmds (no x_prefix even tho ...)
	if "$cmd"=="gendist" & "`proximities'"!=""  local prfxlst = "`prfxlst' x"
	if "$cmd"=="gendummies"	 local prfxlst = "du"			// Assign generally 2-char identirying char(s) for gendu and genme (below)
	if "$cmd"=="geniimpute"  local prfxlst = "i m"
	if "$cmd"=="genmeanstats" local prfxlst = "np mn sd mi ma sk ku su sw me mo" 
	if "$cmd"=="genplace"  local prfxlst = "i m p"
	if "$cmd"=="genyhats" & "$multivariate"!="" local prfxlst = "d"	// (if multivariate WAS optioned)
	if "$cmd"=="genyhats" & "$multivariate"=="" local prfxlst = "i" // (if multivariate was NOT optioned)
	
	scalar PRFXLST = "`prfxlst'"							// Put into scalar to make it accessible elsewhere
*/															// ABOVE CODE SEEMINGLY UNUSED `COS `prfxlst' IS NOT REFERENCED ANYWHERE	***
	
	
	local ic = substr("`cmd'",4,1)							// `ic' (for identirying char(s) is used to prefix `cmd'P-generated vars
	if "`cmd'"=="genmeanstats" | "`cmd'"=="gendummies"  local ic = substr("`cmd'",4,2)
															// One identirying char(s) in general but two chars for gendu and genme

	local aprfx = "_"										// Put default "_" `into `aprx'
	if "`aprefix'"!=""  {									// If user employed the 'aprefix' option ..
	   local aprfx = "`aprefix'"							// Replace "_" with optioned string
	}
	local aprefix = "`aprfx'"								// And put the result back into `aprefix'
	

	
*	*************											// Subprog gets lists of inputs, outcomes to convert to globals below
    getoutcmnames , depvarname(`depvarname') aprefix(`aprefix') proximities(`proximities') multivariate(`multivariate')
	if "$SMreport"!=""  exit								// If returning from errexit, exit to next level up
*	*************											// 'getoutcmnames' HAS 'IRONED OUT' VARIABLE TYPES AND MULTIVARLISTS
															// (whatever their origin, any var to be newly created gets equal status)

															// SCALARS THAT USED TO BE GLOBALS NOW MUST BE ACCESSED AS LOCALS
	local outcmnames = OUTCMNAMES							// There are as many`outcmnames' as there are different outcome prfxs
	local inputnames = INPUTNAMES							// There are as many`inputnames' as there are different outcome prfxs
	local prfxvars = PRFXNAMES								// Ditto (CALLING THEM prfxvars IS UNFORTUNATE LEGACY NAMING CHOICE)		***
	local varlistno = VARLISTNO								// There are as many `varlistnos' as there were varlists
	local stubnames = STUBNAMES								// Same for the `gendummies' `stubnames' if STUBNAMES is not missing
	local optnames = OPTNAMES								// Save having to initialize these again for this subprogram
	local spfxlst = SPFXLST									// ('genme' has the same multiplier in regard to stat names in $statlst)
															// (EACH SCALAR WORD IS EITHER NAME/STRING/# OR MISSING, CODED AS A PERIOD)	
	

	local rename = ""										// List of vars to be temporarly renamed until user ops are implementd
															// (at end of 'cleanup', which is final subprogram called by wrapper)	
	global namechange = ""									// Will hold list of varnames temporarily changed to avoid name conflicts
	global badivars = ""									// Will hold list of orphened ivars w existng names matched by `cmd'P vars
															// (presumably left orphened by error exit prior to 'cleanup' renaming)
	global badovars = ""									// Will hold list of ovars w names matchd by existng stackMe-generatd vars
															// (perhaps left orphened by error exit; perhaps user error) 
	local upv = ""											// Will hold list of existing vars with upper case first characters
															// (presumably left after error exit before being renamed w lower case)
															// (temporary global used only within this codeblk)
	local badchoice = ""									// Will hold list of ovarnames made conflictual by chosen user options
															// COULDNT THINK HOW TO DO THIS

*pause on

pause getprfxdv(1)
global errloc "getprfxdv(1)"

	   
											// (1)	 BUILD LIST OF VARS TEMPORARILY RENAMED, WITH "___" INITIAL PREFIXE (AND
											// 		 APPARENTLY REMAINING IN DATASET DUE TO UNTIMELY ERROR EXIT) THAT NEED TO BE
											//		 DROPPED SO AS TO AVOID NAMING CONFLICTS WITH NEWLY GENERATED U.C. PREFIXED
 											//		 VARS. THIS CODEBLOCK MUST COME FIRST SO AS TO AVOID CONFUSION WITH VARIABLES
											//		 WHOSE FIRST PREFIX CARACTER IS NEWLY MADE UPPER CASE.
											

	

	local nnames = wordcount("`outcmnames'")
	  
	forvalues i = 1/`nnames'	{							// Inspect each varname
	
	    local oname = word("`outcmnames'",`i')				// `outcmnames' already has full prefix for each as yet non-existnt varname
	    local iname = word("`inputnames'",`i')				// `inputnames' is still just the varname typed by user
		local sname = word("`stubnames'",`i')				// This local obtained from one of the scalars unpacked in codeblk(0)
		if "`sname'"=="." local sname = "" 	
															// (gives us the 'gendummies' outcome stub, if `cmd' is 'gendummies')
															// We are cycling thru these three lists (matched on outcome variable name)
		if substr("`oname'",1,3)=="___" drop ___* 			// If any ___* vars are hanging around after error exit, drop all of them	
															// ("___" PREFIX IS PROGRAM-ASSIGNED NOT USER-DEFINED; DK WHY IGNORED THIS)	***
	} //next `i'->oname										// NOTE THAT `iname' AND `oname' ARE OFTEN THE SAME NAMES AND, AS YET
															//  ONLY `iname' MAY ACTUALLY EXIST AS A VARIABLE
	
	
	
	
	
	
pause getprfxdv(2)
global errloc "getprfxdv(2)"


											// (2) ADDRESS ANY NEW VARNAMES THAT CLASH WITH EXISTING NAMES BUT WILL LATER BE RENAMED
											//	   CODE THAT CREATES THE POTENTIALLY ORPHENED U.C. PREFIXES WE HAD TO DEAL WITH ABOVE
														
		
	local nnames = wordcount("`outcmnames'")					  

	  
	forvalues i = 1/`nnames'  {								// Inspect each varname
			
	   local oname = word("`outcmnames'",`i')				// `outcmnames' already has full prefix for each as yet non-existnt varname
	   local iname = word("`inputnames'",`i')				// `inputnames' is still just the varname typed by user (duped per oname)
	   local temp = "`iname'"								// (`iname' may be `sname' for 'gendu'; using `temp' avoids schlckng `iname'
	   local pf = word("`spfxlst'",`i') 					// `i' index gives us word # for correspondng `cmd'P-generated interim name
	   local sname = word("`stubnames'",`i')				// This local returned from 'getoutcmnames' where retrieved in codeblk(0)
	   if "`sname'"!="."&"`sname'"!="" local temp="`sname'" // If that word is NOT coded missing ("."), replace `iname' with it
															// (gives us the 'gendummies' outcome stub, if `cmd' is 'gendummies')
															// We are cycling thru these four lists (matched on outcome variable name)
	   capture confirm variable `oname'
	   if _rc==0   local rename = "`rename' `oname'"		// If `oname exists' add to list of vars to be renamed
	   if "`pf'"!="." {										// If `spfxlst' was not empty for this varlist..
	      capture confirm variable "`pf'_`temp'"			// (temp is either an 'iname' or, for 'gendu', maybe a stubname)
	      if _rc==0  local rename = "'rename' `pf'_`temp'"	// Same for `cmd'P-generated interim variable
	   }
	   
	   //IN ABOVE CODE NEED TO VERIFY THAT CONFLICTING NAME WILL NO LONGER BE A PROBLEM AFTER RENAMING THAT HAPPENS IN 'cleanup'. HOW??	***

	} //next `i'->oname
	
	
	if "`rename'"!=""  {									// If `rename' is not empty..
		
		foreach name of local rename  {						// Cycle thru all names in list
/*	   	  
			local ist = strupper(substr("`name'",1,1))		// Make first char of prfx upper case (UC) (prfxs are otherwise always LC)
			local upname = "`ist'" + substr("`name'",2,.)	// Construct new name by prepndng that UC char to rest of originl name
*/															// ABOVE LINES COMMENTED OUT 'COS WE ADOPTED QUASI-MISSING ALTERNATIVE
*			**********************
			rename `name' ___`name'							// THIS IS THE MONEY COMMAND WHERE PRECAUTIONARY RENAMING IS DONE
*			**********************
			global namechange = "$namechange ___`name'"		// Add the new name to global list of strs needing previous names restored															// (this will be done as final task of subprogram 'cleanup')
		} //next `name'
															// (it is the possible exit before doing this that calls for cdblk 1 above)
	} //endif `rename'
	
	
	
	
	
pause getprfxdv(3)
global errloc "getprfxdv(3)"

											// (3) 	DEAL WITH NEW VARNAMES THAT STILL CLASH AFTER ABOVE TEMPORARY RENAMING.
											// 		BEARING IN MIND THAT BOTH INPUT AND OUTCOME NAMES WILL BE GENERATED LATER,
											//   	ENSURE NO OUTCOME NAMES CONFLICT WITH EXISTING VARNAMES (OR WITH `cmd'P-GENERATED 
											//		INTERIM NAMES); BUILD LIST OF VARNAMES THAT WILL REMAIN CONFLICTED EVEN AFTER 
											//		USER-OPTIONED NAME-CHANGES HAVE BEEN IMPLEMENTED; ASK USER FOR PERMISSION TO 
											//		REPLACE SUCH VARIABLES. 
											//		(NOTE THAT, FOR `genmeamstats', `cmd'P PREFIXES ARE STORED AS `opt' NAMES)
																				
								

	local nnames = wordcount("`outcmnames'")				// Obtain count in `nvars' for number of outcome names
														    // (same as n of inputvars and spfxlst strings – all w matching vars)															
	forvalues i = 1/`nnames'  {								// Inspect each varname
	
		local oname = word("`outcmnames'",`i')				// List of all the vars to ultimately be generated
		local iname = word("inputnames'",`i')				// List of original names on which outcomes are built
		local temp = "`iname'"								// (so there are as many inputnames per variable as optnames for this `cmd')
		local sname = word("`stubnames'",`i')				// This local returned from 'getoutcmnames' where retrieved in codeblk(0)
		if "`sname'"!="."&"`sname'"!="" local temp="`sname'" // For 'gendummies', iname may come from `stubnames' (avoid schlocking it)
															// (for `iname' (now `temp', an `ic' prefix is added by default)	   				
		capture confirm variable "`ic'_`temp'"				// If `cmd'P-generated `ic'_`temp' names a variable that already exists 
		if _rc==0  {										// (presumably after a previous error exit)..
			global badivars = "$badivars `ic'_`temp'" 		// Add to list of `badivars'
		}	   												// (this list includes `sname' vars that already exist)

		capture confirm variable `oname'					// (distinguished from inames `cos they call for a specific error message)
		if _rc==0  {										// If `oname' exists 
			global badovars = "$badovars `oname'"			// Add to list of badovars
			
		} //endif _rc										// IDEA FOR FUTURE CONSIDERATION: CREATE AN SMcleanup UTILITY				***
															// (Use stackMe utility program SMcleanup to rid dataset of all such)
	} //next `i'->name

		
	if "$badivars"!=""  {									// If we found name conflicts for ivars in code above..
															// (distinguished because they call for a specific error message)	
		dispLine "Listed vars likely remain after error exit that orphened them: $badivars; drop them & continue. ok?" "aserr"
*				  12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		local rmsg = r(msg)								
		capture window stopbox rusure "`rmsg'"
		if _rc  {											// If user did not respond with 'ok'
			errexit "Lacking permission to drop listed vars, will exit on 'ok"
			exit
		}
	   
		else  {												// Else drop these variables
		  foreach var of global badivars  {
			capture drop `var'
		  }
		} //endelse							
		
	} //endif $badivars
	

	if "$badovars"!=""  {									// If we found name conflicts for ovars in code above..
															// (distinguished because they call for a specific error message)
		dispLine "Listed vars already exist: $badovars; drop them to continue. Replace?" "aserr"
		local rmsg = r(msg)									// Retrieve displayed msg reformatted for window stopbox
		
		capture window stopbox rusure "`rmsg'"
		if _rc  {											// If user did not respond with 'ok'
			errexit "Lacking permission to drop listed vars, will exit on 'ok'"
			exit
		}
	   
		else  {												// Else drop these variables
		   foreach var of global badovars  {
			  capture drop `var'
		   }
		} //endelse
	
	} //eudif $badovars

									
	
	local skipcapture = "skip"								// Flag to skip the endcapture block if entered it from here
	

* **************	
  } //endcapture											
* **************
pause off
 
  if _rc & "`skipcapture'"==""  {
   	 errexit "Error in $errloc"
     exit
  }
														
	
	
end getprfxdvars




********************************************************************************************************************************




capture program drop getwtvars

program define getwtvars, rclass
										// Identify and save weight variable(s), if present, to be kept in working dta
global errloc "getwtvars"

	args wtexp
	
*	*****************
	capture noisily {
*	*****************
										
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
		  
		  if "`wtvar1' `wtvar2'"==" "  {						// If both locals are non-empty, the string will contain one space
		  	errexit "Clarify weight expression: use (perhaps parenthesized) varname at start or end"
			exit
		  }
		  
		} //endif 'wtexp'
		
		return local wtvars `keepv'
		
		local skipcapture = "skip"

*	**************
	} //endcapture
*	**************
	
    if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
    }
														
	

end getwtvars



********************************************************************************************************************************



capture program drop isnewvar								// NO LONGER CALLED from getprfxdvars 										***


program isnewvar											

version 9.0


  global errloc "isnewvar"
  
  local prfxdnames = PRFXDNAMES
  
  global newprfxdnames = ""
	
	
* *****************
  capture noisily {
* *****************

*	*******************************
	syntax anything, prefix(string)
*	*******************************
	
	if "`prefix'"=="null"  local prefix = ""				// No prefix will be prepended to anything-var if prefix is "null"/empty
	else local prefix = "`prefix'_"							// Else add underline to end of 'prefix'
	
	local ncheck : list sizeof anything						// 'anything' may have several varnames
	
	forvalues i = 1/`ncheck'  {								// anything already has default prefix for each var
	
	  local var = word("`anything'",`i')
	  if substr("`var'",1,2)!="__"  {						// If `var' is not a tempvar
	  
	    if "`prefix'"!=""  local var = "`prefix'_`var'"		// If a(n additional) prefix was optioned
		
		if strpos("`var'","_")==2  {						// If this was a single-character prefix
		
		}

		
	    capture confirm variable `var'						// These vars have their final prefixes (default or optioned)
	    if _rc==0  {										// If that variable already exists ...
	      global prfxdnames = "`prfxdnames' `var'"				// Add to global list final names of outcome vars
		  global exists = "$exists `var'"					// Add to global list initial names of corresponding inputs
	    }													// (but not ALL new vars may have prefix – eg gendummies)
	    else local newprfxdnames = "`newprfxdnames' `var'"	// List of prefixed outcomes that don't yet exist (APPARENTLY UNUSED)		***
	  
*	    mata:st_numscalar("a", ascii(substr("`var'",1,1))) 	// Get MATA to tell us the ascii value of the initial char in `var'
*	    if a>64 & a<91  continue							// Skip any vars having prefixes whose 1st char is upper case
															// (COMMENTED OUT and now put into list of $badvars, below)
	    local prfx = strupper(substr("`var'",1,1))			// Extract minimal prefix from head of 'var' & change to upper case
	    local badvar = "`prfx'"+substr("`var'",2,.)			// Potential badvar's prefix now has upper case 1st char
	    capture confirm variable `badvar'					// Confirm that such a var is left over from previous error exit
	    if _rc==0  {
	  	  global badvars = "$badvars `badvar'"				// If so, add to list of such vars
		} //endif
		
	  } //endif substr..
	  
	} //next i (becomes var)
	
	local skipcapture = "skip"

* **************
  } //endcapture
* **************
  
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
   }
														
  
	
end //isnewvar




********************************************************************************************************************************




capture program drop showdiag1								// Called from wrapper(6) to set up for diagnostic displays if optioned

program define showdiag1									// Prepares to display diagnostics and extra diagnostics if optioned


global errloc "showdiag1"


*	*****************
	capture noisily {
*	*****************


		args limitdiag c nc nvarlst
		
		if "$cmd"=="genstacks" {									  // For cmd genstacks we by-pass normal sources for vartest
			if `nvarlst'==0  local nvarlst = 1
			local vartest = "$genstkvars"
		}
		
		forvalues nvl = 1/`nvarlst'  {

				if "$cmd"!="genstacks"  local vartest = VARLISTS`nvarlst' // For most cmds get 'vartest' from this scalar

				   local vartest = subinstr("`vartest'",".","",.)	  // Remove any missing-symbols (DK where they come from)
				   unab vartest : `vartest'	

				   local test : list uniq vartest					  // Strip any duplicates of vars in vartest; put result in 'test'
				   local nvars = wordcount("`test'")
				   scalar minN = .									  // (a big number)
				   scalar maxN = -999999

				   global noobsvarlst = ""							  // Local will hold list of vars with no obs in this context
				   
				   foreach var  of  local test  {					  // For each var in 'vartest' (now 'test')
						
						tempvar misvar count						  // Create temporary vars to count N of missing
						qui gen `misvar' = missing(`var')			  // Code mis'var' =0, or =1 if missing
						qui capture count if ! `misvar'				  // Unless error, yields r(N)==0 if var does not exist
						local rN = r(N)
						local rc = _rc								  // Place command in left margin because of how it prints
					    if `rc' & `rc'!=2000  {						  // If non-zero return code which is not 'no obs'
*						              12345678901234567890123456789012345678901234567890123456789012345678901234567890 
						   errexit "Stata program error `rc' at $errloc – click blue return code for details") "`rc'"
						   exit	
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
		
		} //next 'nvl'
				
				
		if !_rc  {								  		  		// Only execute this codeblk if an error has not called for exit 
			if `rc'!=0 & `rc'!=2000 {						  	// If there was a different error in any 'count' command...
				errexit "Stata error `rc' at $errloc in contxt `lbl' – click blue RC for details" // LBL IS A SCALAR; 'lbl' a local
*						          12345678901234567890123456789012345678901234567890123456789012345678901234567890 
				exit `rc'									  	// Set flag for wrapper to exit after restoring origdata
			}
				   
		} //endif !_rc
					
		local skipcapture = "skip"

		
*	**************
	} //endcapture
*	**************
	
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
   }
														
	

end showdiag1




********************************************************************************************************************************




capture program drop showdiag2											// Called from wrapper(7) to display diagnostics
																		// (partially prepared in `showdiag1')
program define showdiag2												

global errloc "showdiag2"



*	*****************
	capture noisily {
*	*****************


		args limitdiag c nc xtra

			
			if `nc'>1  local multiCntxt = 1							  // Different text for each context than whole dataset
			else local multiCntxt = 0
	
			local numobs = _N										  // Here collect diagnostics for each context 
				   					  
			if $limitdiag>=`c' & "$cmd'="!="geniimpute" {			  // `c' is updated for each different stack & context
																	  // 'geniimpute' prints its own diagnostics
/*				local lbl : label lname `c'							  // Get label for this combination of contexts (COMMENTED OUT 'COS					  
				local lbl = "Context LBL"							  //   LBL IS A SCALAR THAT KEEPS ITS CONTENTS ACROSS PROGRAMS)				***
*/				local lbl = LBL										  // Below we expand what will be displayed
																	  // (`lbl' is a local copy of scalar LBL used within a single program)
				if ! `multiCntxt' {	
					local lbl = "This dataset"
					if "cmd'"=="genstacks"  local lbl = "This dataset now" 
				}													  // Only for 'genstacks' referring to stacked data
					  
				local newline = "_newline"
				if "$cmd"=="genstacks" local newline = ""
*				noisily display "   LBL has `numobs' observations{txt}" `newline'
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
				   local msg = "  Context `lbl' has `numobs' observations"
				   noisily display  "`msg'" 						 // Noisily display the msg

				   if `xtra'  {									 	 // If 'extradiag' was optiond, also for other stacks
					  local other = "Relevant vars "				 // Resulting re-labeling occurs with next display
					  if "$noobsvarlst"!="" & `xtra' {				 // If $noobsvarlst is not empty and 'extradiag'
						local errtxt = ""
						local nwrds = wordcount("$noobsvarlst")
						local word1 = word("$noobsvarlst", 1)
						local wordl = word("$noobsvarlst", -1)		 // Last word is numbered -1 ('wordl' ends w lower L)
						if `nwrds'>2  {
							local word2 = word("$noobsvarlst", 2)
							local errtxt = "`word1' `word2'...`wordl'"
							local errshort = "`word1'...`wordl'"
							if `nwrds'==1 local errtxt = "`word1'"
							if `nwrds'==2 local errtxt = "`word1' word2"
							if strlen("No obs for var(s) `errtxt' in context lbl") > 80 {
								noisily display "No obs for var(s) `errshort' in context lbl"
							}
							else  noisily display "No obs for var(s) `errtxt' in context lbl"
*						          		12345678901234567890123456789012345678901234567890123456789012345678901234567890 
							local other = "Other vars "				 // Ditto
						}
					  }
					  
					  local minN = minN							 	 // Make local copy of scalar minN (set in showdiag1)
					  local maxN = maxN								 // Ditto for maxN
*					  local lbl : label lname `c'
					  local lbl = LBL								 // THE UPPR CASE lbl IS A SCALAR THAT KEEPS ITS VALUE ACROSS PROGRAMS			***
					  local newline = "_newline"
					  if "$cmd"=="genstacks" local newline = ""
					  
					  if `multiCntxt'  noisily display 				/// geniimpute displays its own diags
						 "`other'in context `lbl' have between `minN' and `maxN' valid obs"						 
*					  noisily display "{txt}" _continue

				   } //endif 'xtra'
				
				} //endif 'displ'
						 
			} //endif 'limitdiag'

			if `c'==`nc'  capture scalar drop minN maxN				// If this is the final context, drop scalars
			
			local skipcapture = "skip"

			
*	**************
	} //endcapture
*	**************
	
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
   }
														
	
			
end showdiag2



********************************************************************************************************************************


capture program drop stubsImpliedByVars			// Called from 'genstacksO'

program define stubsImpliedByVars, rclass		// Subprogram produces a list of stubs corresponding to multiple varlists
												// (checks those names in case they match already extant varnames)

global errloc "stubsImpl"


* *****************
  capture noisily {
* *****************


	global errloc "stubsImpl"

	local stubslist = ""										// Will hold suffix-free pipes-free copy of what user typed
				
	local postpipes = "`0'"										// Pretend what user typed started with "||", now stripped
	
	while "`postpipes'"!=""  {									// While there is anything left in what user typed
	
	   gettoken prepipes postpipes : postpipes, parse("||")		// Get all up to "||", if any, or end of commandline
	   if substr(strtrim("`postpipes'"),1,2)=="||"  {			// If (trimmed) postpipes starts with (more) pipes
		  local postpipes = substr("`postpipes'",3,.)			// Strip them from head of postpipes
	   }
*	   **********************	   
	   checkvars "`prepipes'"									// 'checkvars' elaborates unab; will collct invald vars in 'errlst'
	   if "$SMreport"!=""  exit									// See if error was reported by program called above
*	   **********************
	   local errlst = r(errlst)
	   if "`errlst'"=="."  local errlst = ""					// SEEMINGLY r(errlst) RETURNS "." RATHER THAN ""					***
	   if "`errlst'"!=""  {										// If there are any such...
		   if wordcount("`errlst'")==1  {
		   	  errexit "Varname `errlst' is invalid"
			  exit
		   }
		   else  {
		   	  dispLine "Invalid varnames: `errlst'" "aserr"
			  errexit, msg("Invalid varnames – see displayed list")
		   }
	   }
	   
	   local vars = r(checked)
	   if "`vars'"==""  {
	   	  errexit "Stubs do not yield any corresponding variables"	// ??															***
		  exit
	   }
	   
	   local 0 = "`vars'"										// Pretend user typed only one varlist; put back in '0'

*	   **************************
	   syntax namelist(name=keep)								// Put names into local 'keep'
*	   **************************

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
			exit
		  }														// Error exit if next stub belongs to a different varlist						
	   } //next while "`stlist'"								// Exit this loop when `stlist' has no more stubs
	   
	   local stubslist = "`stubslist' `stub'"					// Append to stub
	   
	} //next pipes
	
	return local stubs `stubslist'								// Put accumulated stubs into r(stubs)
	
	local skipcapture = "skip"

* **************
  } //endcapture
* **************
  
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
   }
														

																	
end stubsImpliedByVars



********************************************************************************************************************************

	
capture program drop subinoptarg					// Was called from wrapper, but perhaps no longer

program define subinoptarg, rclass					// Program to remove supposed vars from varlist if they prove to be strings
													// or for other reasons (IN PRACTICE MAY NOT BE CALLED)
global errloc "subinopta"


* ***************
  capture noisily {
* ***************

*	************************
	syntax , options(string) optname(string) newarg(string) ok(string)
*	************************


	local l = strpos("`options'","`optname'") 					// Find position of option-name in string to be amended
	if `l'>0  {													// If it is present in `options'
		local oldopt = substr("`options'",`l',.)				// extract the string bounded by start of option-name and end
		local m = strpos("`oldopt'", ")" )						// (option's argument ends withn next close parentheses)
		local oldopt = substr("`oldopt'", 1, `m' )  			// Substitute an `optstr' that holds just the optname & argument
		local options = subinstr("`options'","`oldopt'" ,"" ,1)	// Substitute an empty string for the `optstr' that is to be changed
		if "`newarg'"!=""	{									// If text for new argument was supplied
		   local options = substr("`options,'",1,`l'-1) + 	   /// Concatenate pre-option string + new option + post-option string 
			"`optname'(`newarg')"+substr("`options'",`l',.) 	// `newarg' will consist of optname + `newarg' in parentheses
		}													
	}
	else  {
		if "`ok'"==""  {
			errexit "optname not found"							// Programming error
			exit
		}
	}
	return local options `options'
	
	local skipcapture = "skip"

	
*	************
  } //endcapture
*	************
  
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
   }
												


end subinoptarg



********************************************************************************************************************************


capture program drop varsImpliedByStubs			// Called from 'genstacksO', 'cleanup'

program define varsImpliedByStubs, rclass		// Subprogram converts list of variable stubnames to list of vars implied 
												// (eliminating false positives with longer stubs)
global errloc "varsImpl"


* ****************
  capture noisily {
* ****************

*	**************************
	syntax namelist(name=keep)
*	**************************


	if strpos("`keep'","||")>0  {
		errexit "Stublist should not contain '||'"
		exit													// Ensure stublist has no pipes
	}
	
	local varlist = ""											// Accumulating list of vars implied by each stub in turn
	local keepv = ""											// Accumulating list of vars verified as having numeric suffix
	local nstubs = wordcount("`keep'")
	
	forvalues h = 1/`nstubs'  {									// We know that `keep' was filled with stubs by caller 
	
		gettoken k keep : keep									// Repeatedly peel off first word of `keep' (list of stubnames)
		local lenstub = strlen("`k'")							// Get # of chars in stub
		capture unab vars : `k'*								// Get list of vars with this stub 
		
												
											// LIST MIGHT INCLUDE ADDITIONAL VARS WITH LONGER STUBS; DON'T ADD THOSE TO 'keepv'
		foreach var  of  varlist `vars'  {
			local suffix = substr("`var'",`lenstub'+1,.)		// Abstract the suffix for each var
			capture confirm integer number `suffix'				// See if whole suffix is an integer number
			if _rc  continue									// Suffix is not numeric means longer stub so continue w next v
			else  {  											// Else return code is zero, so suffix is numeric
				local keepv = "`keepv' `var'"					// Append var to varlist if its whole suffix is numeric
			}
		} //next 'var'
		
	} //next stub
	
	return local keepv `keepv'
	
	local skipcapture = "skip"
	
	
*  *************
  } //endcapture
*  *************


   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in varsImplied"
      exit
   }
														
  
	
end varsImpliedByStubs



****************************************************** END OF SUBPROGRAMS *****************************************************



/*											// TEST CODE MIGHT BE USEFUL
	mata:st_numscalar("a",ascii("A")) 		// Get MATA to tell us the ascii value of char following "_"
	display a  /*–  upper case A is 65;  upper case Z is 90 */
*/
/*
*set trace on
local v = "REDU1"
	   while real(substr("`v'",-1,1))<.  {					// If conversion to real is not missing, last char is a number
		  local `v' = substr("`v'",1,strlen("`v'")-1) 		// (so remove that char from end of string and repeat)
		  display "`v'"
	   } //next while										// Hopefully string now ends in generic name, not specific value
*/

