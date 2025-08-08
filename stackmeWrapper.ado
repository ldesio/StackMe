

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
*!  Version 8 moves further "opening" codeblocks, from 'gendist', 'geniimpute', and 'genstacks' to new `cmd'O programs. 
*!  Version 9 introduces $varlist, $prfxvar, $prfxstr globals so `cmd'P programs need not do so; option to evaluate simpler append code.
*!			  (simpler append code uses file with accumulating contexts and appends current context to that file – seemingly slower!)
 
*!  Stata version 9.0; stackmeWrapper versions 4-9 updatd Apr, Aug '23 & again Apr '24 to May'25 by Mark from major re-write in June'22

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
										// service requied all stackMe commands, simplifying program maintenance and error-correction.
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
										// a combined list uniquely identifying the variables needing to be retained in working dta.
										// As far as possible ensure that the names of variables to be created do not duplicate any 
										// existing names (warn users of possible ensuing name conflicts if these can't be prevented).
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
	global prfxdvars = ""									// Global will hold the list of prefixed vars from subprogram 'isnewvar'.
	global SMreport = ""									// Signals error msg already reportd, to 'errexit' and to calling progrms.
	global exit = 0											// Signals to wrapper the current state of data usage:
															// $exit==1 requires restoration of origdta; $exit==0 or $exit==2 doesn't
															// ('exit 1' is a commnd –sets return code 1–  $exit=1 is flag for caller)
	global nvarlst = 0										// N of varlists on commnd line is initialized to 0 (updatd by `nvarlst')

	local filename : char _dta[filename]					// Get established filename if already set as dta characteristic

	if "`filename'"==""  {
	
		display as error ///
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
		if "`prefix'"!="STKD" & "`prefix'"!="S2KD"  {		// 'errexit' w 'msg' as arg displays msg in results window and also in stopbox
		  window stopbox note "Dataset with SMstkid variable should have filename with STKD_ (or S2KD_) prefix"
*                  12345678901234567890123456789012345678901234567890123456789012345678901234567890
															// (alternatvly put msg into 'msg' option and optionally add 'display' option)
		  local warnexit = "warn"							// Need to warn of implications before exit (alternative path)
		  
		}
	  } //endif _rc
	  
	  else  {
	  	local dblystkd = "dblystkd" 						// Else _rc of 0 shows data are doubly-stacked
		gettoken prefix rest: filename, parse("_") 			// And check for correct prefix to filename

		if `prefix'!="S2KD" {								// 'errexit' w 'msg' as arg displays msg in results window and also in stopbox
		  window stopbox note "Dataset with S2kid variable should have filename with S2KD_ prefix"
															// (alternatvly put msg into 'msg' option and optionally add 'display' option)
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
	
	gettoken cmd rest : (global) save0						// Get the command name from head of local `0' (what the user typed)
															// (saved in global save0 in first lines of this wrapper)
															// (gettoken primes local `rest' for the next 'gettoken', below
	global cmd = "`cmd'"									//  and provides a global accessible from other programs)

	if "`cmd'"=="gendummies" | "`cmd'"=="genmeanstats" local needopts = 0 // These two stackMe commands do not require an options-list
															// ADD ANY OTHER EXCEPTIONS, AS DISCOVERED 									***
	gettoken cmdstr mask : rest, parse("\")					// Split rest' into the command string and the syntax mask
	
	global mask = "`mask'"									// Make a copy to share with getprfxdvars and any other program needing it
						
	gettoken preopt rest : cmdstr, parse(",")				// Locate start of option-string within 'cmdstr' (it follows a comma)
															// ('preopt' will be prepended to 'postopt', below, to make 'multivarlst)
	if "`rest'"!=""  local rest = substr("`rest'",2,.) 		// Strip off "," that heads the mask ('if' clause should redundant)
	if strpos("`rest'",",")>0 {								// Flag an error if there is another comma (POSSIBLY SUBJECT TO CHANGE)		***
		local err = "Only one options list is allowed with up to 15 varlists{txt}" // See previous call on 'errmsg' for display options
*               	 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		errexit "`err'"										// Above template counts available 80 colums for one-line results display
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
										//		 of the first argument – an argument that will hold any varname or list of varnames 
										//		 that might be supported by a stackMe command and might instead be supplied by a 
										//		 pre-colon prefixlist prepended to each varlist (varlist prefixes can be different 
										//		 for each varlist whereas options cannot).
										//		 *********************************************************************************		 
	
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
	global mask = "`mask'"									// Make a global copy for subprograms (e.g.'getprfxdvars') that need it
	gettoken preparen postparen : mask, parse("(")			// Identify the option-name for critical 1st option by parsing on "("
	local opt1 = lower("`preparen'")						// Deal with any capitalized initial chars in this option name
															// (leaves the lower case version of 1st optn in 'opt1', needed below)
	local saveoptions = "`options' `prfxtyp'"				// Append 'prfxtyp' to 'options' so it can be parsed by syntax command
															// (along with user-supplied options)
	
	
	
	
	
*} //endcapture
																	
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
	 
		local opts = "`options'"						// Cannot use `options' local as that gets overwritten by syntax cmd)\
		
		gettoken opt rest : opts, parse("(")			// Extract optname preceeding 1st open paren, else whole of word
														// NOTE: 'opt' and 'opts' are different locals
		if "`cmd'"=="gendist"  {
		   if "`respondent'"!=""   {
		      errexit "Option 'respondent' is option 'selfplace' in version 2" // 'msg' as argument is both displayed and windowed
			  exit										// ('msg' as option is windowed but needs 'display' option to be displayed)
		   }											// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
		}
		
		

														// ('ifin' exprssns must be appended to first varlist, if more than one)
		local 0 = ",`opts' "  							// Named opts on following syntax cmd are common to all stackMe commands 		
														// (they supplement `mask' in `0' where syntax cmd expects to find them)
														// Initial `mask' (coded in the wrapper's calling `cmd' and pre-processed
														//  in codeblock 0 above) would apply to all option-lists in 'multioptlst'
														//											 (dropped from current versn)
*		***************									// (NEW and MOD in this syntax command anticipate future development)			***
		syntax , [ `mask'  NODiag EXTradiag REPlace CONtextvars(varlist) NOCONtextvars NOSTAcks prfxtyp(string) SPDtst * ] 
/*	    **************/	  							  	// `mask' was establishd in caller `cmd' and preprocessd in codeblk (0.2)
														// (Option SPDtst uses supposedly slower but simpler append file code)
														// (Final asterisk in 'syntax' places unmatched options in `options')
		if "`options'"!=""  {							// (So here check for user option(s) that don't match one listed above)
		
		   if "cmd'"!="genstacks"  {					// Except for command 'genstacks', for which ...
		   
			  foreach opt  in  nosta  {					// 'nostacks' (perhaps more – hence 'foreach') is optional for all but genstacks
				 gettoken head tail : tail, parse("(")	// Put each options string in turn, up to the first/next "(", into 'head"
				 if substr("`head'",1,5)=="`opt'"  {	// If 'head' is "(nocon'" (minimum version of "(nocontexts)")
					local tail = substr("`tail'",1,strpos(")"))				  // `tail' has whatever else the user typed, up to ")"
					local options = subinstr("`options'","`head'`tail'","",1) // Substitute "" for options-string "`head'`tail'", once
				 } //endif
			  } //next `opt', if any					// (any additional exceptional `opt's would be added to 'foreach's "nosta")
			  
		   } //endif `genstacks'
		   
		   if "`options'"!=""  {						// If, after removing the above 'options'-string still has any options remaining
			  display as error "Option(s) invalid for this cmd: `options'"
			  errexit, msg("Option(s) invalid for this cmd: `options'")
														// Call on 'errexit' with optioned msg suppresses display, done just above
			  exit										// 'exit' cmd returns to caller, skipping rest of wrapper incldng skipcapture
		   }
		   
		} //endif 'options'												


		local lstwd = word("`opts'", wordcount("`opts'"))	// Extract last word of `opts', placed there in 0.2 & parsed above
		
		**************************
		local optionsP = subinword("`opts'","`lstwd'","",1)	// Save 'opts' minus its last word (the added 'prfxtyp' option)
*		**************************							// (put in 'optionsP' at end of codeblk 1.1 for use solely in wrapper)

															//*****************************************************************
		local optionsP ="`optionsP' limitdiag(`limitdiag')" // Append 'limitdiag' which got lost somewhere
															// (perhaps indication that other options might have been lost too)			***
*															//******************************************************************

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
		
		if "`aprefix'"!=""  {								// If 'aprefix' has been optioned with 'gendummies' or 'genmeanstats'
		   if "`cmd'"=="gendummies" | "`cmd'"=="genmeanstats"  noisily display ///
			  "{err}WARNING:{txt} aprefix option for gendu or genme can yield an undiagnosed varname conflict"
		} //endif	//         12345678901234567890123456789012345678901234567890123456789012345678901234567890
		

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

*			*******************************
			checkvars "`contexts'" "noexit"				// Unab the vars in 'contexts', also dealing with hyphenated varlists
			if "$SMreport"!=""  exit 					// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
*			*******************************				// 'SMreport' is only set by errexit, so this tells us there was an error

			local errlst = r(errlst)					// Returned by 'checkvars'
			local errlst =subinstr("`errlst'",".","",.) // Substitute null strings for missing symbols
			if "`errlst'"!=""   {						// If result is non-empty ...
				dispLine "This file's charactrstic names contextvar(s) that don't exist: `errlst'{txt}" "aserr"
				display as error ///
		        "Use utility command {help stackme##SMsetcontexts:SMsetcontexts} to establish correct contextvars{txt}"
*		                 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				errexit, msg("This file's contextvars charactrstic names variable(s) that don't exist: `errlst'")
				exit 
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

										// (1.2) Deal with first option, which will hold an indicator variable name if `'prefixtype 
										//		 is "var", else a string (depending on 'cmd'); also with references to SMitem amd
										//		 `itemname'
														
		
		local optad1 = ""								// Will hold indicator or cweight options
	
		local opterr = ""								// Reset opterr 'cos already dealt with previous set of error varnames

	
														// In the general case 'opt1' has name if first option in 'optMask'
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
		
*	  	  *****************************
		  checkvars "``opt1''"							// Double quotes get us to the varname(s) actually optioned
		  if "$SMreport"!="" exit 						// ($SMreport is empty if return code of 0 was reported)
*	  	  *****************************					// 'exit' cmd returns to caller, skipping rest of wrappr, incldng skipcapture
		  local checked = r(checked)
		   
		  local checked = subinstr("`checked'",".","",.) // Remove any missing variable symbols

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
	
		   ***************	
		   syntax anything [if][in][fw iw aw pw/]					// (trailing "/" ensures that weight 'exp' does not start with "=")
*	       ***************											// Syntax command finds in `anything' following 'ifinwt' & options
																	
						
		   if `nvarlst'==1  {										// If this is the first varlist
		   
			  local ifin = "`if' `in'"								// Ensure 'if' and 'in' expressions occur only on first varlist
		
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
		   } //endif 'nvarlst'==1									// What follows applies to ALL varlists
		   
																	// Here remove 'if' and/or 'in' and their expressions from 'anything'
		   local endv = "if"										// Initially assume end of varlist is marked by "if"
		   if "`if'"=="" & "`in'"!=""  local endv = "in"			// Else assume marker is "in" (or end of varlist)
		   if "`endv'"!=""  gettoken anything rest : anything, parse("`endv'") // 'rest' now has any 'if'|'in'|both; anything has neithr
																	// ('gettoken' removes either or both markers and their expressns)
		   
		   if `nvarlst'>1  {										// Later varlsts should not have ifin expressns
		   
		      local ifin = "`if' `in'"
		   	  if "`ifin'"!=""  {
		   		  errexit "Only 'weight' expressions are allowed on varlists beyond the first; not if or in"
*               		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  exit												// 'exit' command takes us back to caller, skipping rest of wrappr
				  
			  } //endif
			  
		   } //endelse												// 'anything' now contains just varlists or a stublist
		   
		   
		   if "`weight'"!=""  {										// If a weight expression was appended to the current varlist

			  local wtexp = subinstr("[`weight'=`exp']"," ","$",.)	// The trailing "/" in the weight syntax eliminates redundnt blank
																	// Substitute $ for space throughout weight expression
																	// (has to be reversed for each varlist processed in 'cmd'P)
*		 	  ***************										// (ensures one word per weight expression)
			  getwtvars `wtexp'										// Invoke subprogram 'getwtvars' below, maybe calling errexit
			  if "$SMreport"!=""  exit								// Skip rest of wrapper, including 'skipcapture' thru' exit to caller
*		 	  ***************										// $SMreport is empty if getwtvars did not call 'errexit'
	   
			  local wtvars = r(wtvars)
			  if "`wtvars'"=="."  local wtvars = ""					// SEEMINGLY r(wtvars) RETURNS "." WHEN wtvars IS EMPTY				***
			  local keepwtv = "`keepwtv' " + "`wtvars'"				// Append to keepwtv the 1 or 2 vars extracted by prog 'getwtvars'
																	// (use double-quotes to access the var(s) pointed to by `wtvars')
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
		   
*		   ***************************************		  			// (CONCEPTUALLY, THIS PADDING OF 'wtexplst' BELONGS WITH 
		   global wtexplst`nvarlst' = "`wtexplst'"					//   $varlists`nvarlst', ETC., FILLED AT END CODEBLK(2.1); dealt
*		   ***************************************					// 	 with here 'cos there is one per varlist)

			
*		   *************************************************
		   local multivarlst = "`multivarlst' `anything' ||"		// Here multivarlst is reconstructed without any 'ifinwt' expressns
*		   *************************************************		// (any such were removed by Stata's syntax command; instead weights

			

			
			
			

global errloc "wrapper(2.1)"
pause (2.1)


										//		 *******************************************************************************************
										// (2.1) Here check the validity of vars split into in 'inputs' and 'outcomes' for each varlist. All
										//		 outcome variables get names based on input varnames (except with gendummies, if stubnames
										//		 are optioned/listd that provide outcome varnames). Vars we here call 'inputs' are vars that 
										//		 provide additional data needed to generate desired outcomes, but without defining the out-
										//		 come variable name (except for genyhats, where a prfxvar can provide an outcome name). As
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
										

		     gettoken precolon postcolon : anything, parse(":")		// Parse components of 'anything' based on presence of ":", if any,
	
			 if "`postcolon'"==""  {								// If 'postcolon' is empty then there is no colon
																	// (FOR GENYHATS, no colon indicates generation of bivariate yhats)
			   local prfxvar = ""									// If there is no colon, store empty string for prfxvar, & the followng
			   local strprfx = "null"								// Placeholder for strprfx (there can only be one strprfx per varlst)
			   local vars = "`anything'"							// Vars provide most outcomes (with colon some pre-processing is needed)
			   														// (even for gendu and genyh whose precolons get special treatment)
			   local input = ""										// (by default there are no inputs other than those becoming outcomes)
			   
		     } //endif 'postcolon'									// (could use r(checked) instead of 'anything'; which may have hyphens)
		   
		     else  {												// THERE IS A COLON, so 'inputs' will get (perhaps tail of) 'precolon'
		   
			   local vars = strtrim(substr("`postcolon'",2,.))		// 'vars' is tail of 'postcolon' after ":" is removed from its head  
																	// (for gendummies the tail vars would no longer provide stubnames)
			   gettoken preul postul : precolon, parse("_")			// 'precolon' may itself be prefixed by using underline (ul) as divider
			   if "`postul'"==""  {									// If 'postul' is empty then there is no "_" divider
			   	  local strprfx = "null"							// And 'prfxvar's have no prefix string, so store a placeholder
				  if "`cmd'"=="gendummies'" local stub="`precolon'" // For gendummies, precolon would hold stubname(s) (not yet var(s))
				  else local prfxvar = "`precolon'"					// For other commands, colon is preceded by an input variable or varlist
			   }													
			   
			   else  {												// Else 'postul' holds the prfxvar(s)
			   	  local strprfx = "`preul'"							// And 'preul' has a string prefix for that var or varlist
				  if "`cmd'"=="gendummies'" local stub = substr("`postul'",2,.) // (there may be multiple stubs, but only one strprfx)
				  else  local prfxvar = substr("`postul'",2,.)		// In either case, strip leading "_" from prfxvar(list) 
			   } //endelse											// (So there can be no more than one prefixed var or stub per varlist)
			   
			 } //endelse											// That covers all possible varlist formats
			 
			 if "`cmd'"!="gendummies"  {
			 	local input = "`prfxvar'"							// (prfxvars are supplementary inputs or, for gendummies, stubnames)
				checkvars "`input'"
				local prfxvar = r(checked)							// (deals with hyphenatd and abbreviatd vars; othr vars get checkd below)
				local input = "`prfxvar'"
			 }
			 
			 local outcome = "`vars'"								// By default vars provide the outcome varnames (see above for gendu)
			 checkvars "`outcome'"									// (ALL COMMANDS USE PREFIX STRINGS to modify outcome varnames)
			 local vars = r(checked)								// (those are NOT THE SAME as the prefix strings in this codeblock)
			 local outcome = "`vars'"							 	// But, even for genyhats, other vars are also outcomes	
																	// (deals with hyphenatd and abbreviatd vars; prfxvars got checkd above)
			 if "`cmd'"=="gendummies" {
			    unab vlist : `vars'									// For gendummies, `vars' always identifies the inputs
				local nvars = wordcount("`vlist'")					// Find length of outcome varlist
				local nstubs = wordcount("`stub'")					// (gendummies may have multiple stubnames)
				if "`stub'"!=""  {
				   if `nvars'!=`nstubs'  {							// If there are any stubs, ensure as many stubnames as variables
			   	      errexit "gendummies must have as many stubnames as varnames in each pipe-delimitd varlist"
																	// (not mentioned is that a single stub can have a strprfx)
*               		       12345678901234567890123456789012345678901234567890123456789012345678901234567890
		 			  exit											// Exit to caller after error is reported by errexit
				   } //endif `nvars'!=`nstubs'
				} //endif `stub'"!=""
			 } //endif 'cmd'=="gendummies		
			 
			 local warned = 0										// Flag prevents warning from being duplicated
			 if `limitdiag' & "`strprfx'"!="null" & !`warned' {		// (this error can occur for any command that has an opt1 var(list))
				noisily display _newline "NOTE: Prefix to varname overrides, for that varname, any `opt1' option{txt}"
				local warned = 1									// 'opt1' is the first option in every stackMe cmd's option list
			 }														// (it is the option that will be replaced by any 'prfxvars')
		 
			 if "`prfxvar'"!="" local prfxvars ="`prfxvars' `prfxvar'"    // Cumulate list of prfxvars over varlists
			 
			 if "`cmd'"=="genyhats'" local outcome ="`outcome' `prfxvar'" // (for genyhats, any 'prfxvar' is an 'outcome')
			 
			 if "`outcome'"!="" local outcomes = "`outcomes' `outcome'"	  // NOTE THAT plurals CUMULATE OVER ALL VARLISTS
		  
			 if "`input'"!=""   local inputs = "`inputs' `input'"	// Just a formality, to conform with outputs 	  
		  		
																	
*			**************************************					// Here is the first step in accellerating all 'cmd'P programs
			scalar NVARLSTS = `nvarlst'								// Puts in scalar # of current varlist; ultimately n of varlists
			scalar VARLISTS`nvarlst' = "`outcome'"					// Store in scalar where can be found by 'cmd'P and elsewhere
			scalar PRFXVARS`nvarlst' = "`prfxvar'"					// Store in scalar the name of var(list) that preceed a colon
			scalar PRFXSTRS`nvarlst' = "`strprfx'"					// String that may prefix a prfxvar(list) – matching n of prfxvars
			scalar VARSTUBS`nvarlst' = "`stubs'"					// (List of) stub(s) matchng N of vars in crrnt varlist (only gendu)
*			**************************************					// PARALLEL GLOBAL wtexplst`nvarlst' WAS FILLED IN CODEBLOCK (2)


			local outcome = ""										// This string needs to be emptied for next varlist
			local input = ""										// Ditto
			local prfxvar = ""										// Ditto
			local strprfx = ""										// And ditto
							
			if `lastvarlst'  continue, break						// If this was identified as the final list of vars or stubs,						
																	// ('break' ensures next line to be executed follows "} next while")
											
*	   	 ****************											****************************************************************
		 } //next `while'											// End of code processing successive varlists within multivarlst
*	     ****************											// Local lists processed below cover all varlists in multivarlst	
*																	****************************************************************
											
	
		local llen : list sizeof wtexplst							// Finish up the wtexplst now all varlists have been processed	
		while `llen'<`nvarlst'  {	
			local wtexplst = "`wtexplst' null"						// Pad any terminal missing 'wtexplst's (must be after 'next while')
			local llen : list sizeof wtexplst
		}
	
*	  	************************************
		local keepifwt = "`ifvar' `keepwtv'"						// Must be appended after exiting 'while' loop `cos only done once 
*	  	************************************						// (list of vars/stubs will provide names of vars generatd by 'cmd'
																	//  per varlst were encoded in $wtexplst' in (2), updated just above)


																	
																	
*	 ********************											***********************************************************																	
	} //endif ! genstacks											// End of codeblockS executed for all cmds except genstacks	
*	 ********************											***********************************************************																
																
	global limitdiag = `limitdiag'									// (first point at which this global can be set by all commands)

				
				
*	*******************
	checkSM "`inputs' `outcomes'"									// Establishes whether SMvars are referenced in either local
	if "$SMreport"!=""  exit 										// Short-cut skips remainder of wrapper including 'skipcapture'
*	*******************												// (if 'errexit' was called from 'checkSM')

	local gotSMvars = r(gotSMvars)									// 'gotSMvars' is list of any SMvars in the active data
	local gotSMvars = subinstr("`gotSMvars'",".","",.) 				// Remove any missing variable symbols

																	// WE DEAL WITH THESE IN CODEBLK (5)

			
																	// ********************************************************
*	*********************************								// Update 'keepvars' with additions from this codeblock
	local keeplist = strtrim(stritrim("`keepoptvars' `keepifwt' `inputs' `outcomes' `gotSMvars'"))
																	// All vars identified for working data are now in keepvars
	local keepvars = strtrim(subinstr("`keeplist'",".","",.))		// Eliminate any "." in 'keepvarlsts' (DK where orignatd)
*	*********************************								// ********************************************************
	
	
	
	noisily display ".." _continue
	global busydots = "yes"											// Flag indicates previous display ended with _continue

	

	

global errloc "wrapper(3)"	
pause (3)

		
										// (3) Check various options specific to certain commands for correct syntax; add `opt1'
										//	   (and 'opt2 for genplace – the first variable(s) in any optionlist) to 'keep' list 
										//	   if the option(s) name variable(s).


	forvalues nvl = 1/`nvarlst'  {								// Cycle thru successive varlists
	   local prfxvars = PRFXVARS`nvl'							// Get prefixvars for that varlist
	   if "`prfxvars'"!=""  {
		  if "`cmd'"!="gendummies" & "`cmd'"!="geniimpute" & "`cmd'"!="genplace"  {
			 if wordcount("`prfxvars'")>1  {
			   	errexit "Only gendummies, geniimpute or genplace can have multiple 'prefix' vars/stubs"
*               		 12345678901234567890123456789012345678901234567890123456789012345678901234567
			    exit											// Exit takes us straight to caller, skipping rest of wrapper
			 } //endif wordcount
		  } //endif wordcount
	   } //endif 'prfxvar'
	   else  {													// Else there is no prefixvar (genyhats can only have one)
	   	  if "`cmd'"=="genyhats" & "`depvar'"=="") { 			// genyhats requires an optioned depvarname if no prefixvar
			 if "`multivariate'"!=""  {
				errexit "For a multivariate analysis with no prefixvar, a depvar must be optioned"
*               	  	   12345678901234567890123456789012345678901234567890123456789012345678901234567
			 }
			 else errexit "For a bivariate analysis (default), a depvar must be optioned" // MAYBE WE SHOULD ALLOW A DEPVARLIST?	***
		  } //endif `cmd'=="genyhats"
	   } //endelse
	} //next 'nvl'
																// End of code interpreting prefix types

	
	if "`cmd'"=="genplace" & "`indicator'"!=""  {				// `genplace' is the only cmd with additional var-naming optn 		***
																// (beyond the 'opt1' option handled above) so handle it here
	   gettoken ifwrd rest : indicator							// See if "if" keyword is first word in 'indicator'
	   if "`ifwrd'"=="if"  {									// If "`indicator'" string starts with "if"
	   if "`rest'"=="" errexit "Missing 'if' expression"
		  tempvar indicator										// If indicator is created with 'ifind', make it a tempvar
		  qui generate `indicator' = 0							// So generate a new var named 'indicator', 0 by default
		  qui replace `indicator' = 1 if `rest'					// Replace values of that variable to accord with 'ifind' expression
	   }														// ('ifind' may include varname(s) but don't need to keep those)
	   else checkvars "`indicator'"								// Else 'indicator' contains a varname; have checkvars check it
		
																// (checkvars will call errexit if no such var exists)
	} //endif 'cmd'=='genplace									// ('indicator' local now names either original or tempvar variable)
	
	
	
																// **************************************************************
	local keepvars =strtrim(stritrim("`keepvars' `indicator'")) // Update 'keepvars' with additions from this codeblock
																// ***************************************************************
							
						
			

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

															
	if "`cmd'" != "genstacks"  {							// 'genstacks' command does not prefix its outcome variables

	

	
*	  *****************										   *********************************************************
	  local keepvars : list uniq keepvars					// Stata-provided function drops duplicate words in any list
*	  *****************										   *********************************************************
	
	
	
	
			
			
			
global errloc "wrapper(5)"			
pause (5)

										//	   *************************************************************************************
										// (5) Deal with possibility that prefixed outcome variables already exist, or will exist
										//	   when default prefixes are changed, per user option. This calls for two lists of
										//	   global variables: one with default prefix strings and one with prefix strings revised 
										//	   in light of user options. Actual renaming in light of user optns happns in the caller
										//	   program for each 'cmd' after processing by 'cmd'P; but users need to known before
										//	   'cmd'P is called whether there are name conflicts. Meanwhile we must deal with any 
										//	   existing names that may conflct with outcome names, perhaps only after renaming.
										//	   *************************************************************************************
										
	  global exists = ""									// Empty list of vars w revised prefixes or otherwise exist as shouldnt
	  local check = ""										// Default-prefixed vars to be checked by subprog `isnewvar' below
	  global prfxdvars = ""									// List of prefixed vars with varnames same as existing prefixed vars
	  global newprfxdvars									// Ditto, for list of NOT already existing outcome vars 
	  global badvars = ""									// Ditto, vars w capitalized prefix, maybe due to prev error exit
	  

															// See if simulated names of outcome vars already exist
*	  ********************									// (identify dups and conflicts, helped by user input)
*	  if "`cmd'"=="gendummmies"  getprfxdvars2 `keepvars', `optionsP' 
	  getprfxdvars `keepvars', `optionsP'					// BUT WE DONT DROP THEM UNTIL WORKING DATA ARE MERGED WITH origdta
	  if "$SMreport"!=""  exit								// Exit takes us straight back to caller, skipping rest of wrapper
*	  ********************									// 'optionsP' holds options needed to identify optioned prefix-strings

	  
	} //endif 'cmd'!='genstacks
	

	
															// ****************************************************************
	if "$cmdSMvars"!=""  {									// (Global cmdSMvars was set in subprogram 'checkSM', invoked above)
															// HERE IS WHERE WE ADD COMMAND-SPECIFIC SMvars TO $exists SO USERS
															//  CAN DECIDE WHETHER TO DROP THEM ($cmdSMvars are set in 'checkSM')
															// ****************************************************************
															
		  foreach v  of  global cmdSMvars  {				// In next lines insert SM names for gendist geniimpute genstacks		***
			 if "`cmd'"=="gendist" & strpos("SMdmisCount SMdmisPlugCount","`v'")>0  global exists = "$exists `v'"
			 if "`cmd'"=="gendummies" & strpos("SMumisCount SMdumisPlugCount","`v'")>0  global exists = "$exists `v'")
			 if "`cmd'"=="gendiimpute" & strpos("SMimisCount SMimisImpCount","`v'")>0  global exists = "$exists `v'"
			 if "`cmd'"=="genstacks" & strpos("SMstkid S2stkid SMitem S2item SMunit S2unit","`v'")>0 global exists = "$exists `v'"
		  }													// APPEND ANY SMvars TO THE exists GLOBAL RETURNED BY getprfxdvars
	}
	
	if "$exists"!=""  {										// $exists holds conflicted varnames found by subprogram getprfxdvars
	
	   dispLine "These outcome variable(s) already exist: $exists – drop these?{txt}" "aserr" // Forty character overhead
*						          12345678901234567890123456789012345678901234567890123456789012345678901234567890 
	   if strlen("$exists")>277  global exists = substr("$exists",1,277) + "..." // Stopbox only holds 320 chars
	   capture window stopbox rusure "Drop outcome variable(s) that already exist?:  $exists"
	   if _rc  {											// Non-zero return code tells us dropping is not ok with user
		 errexit "Lacking permission to drop existing vars"	
		 exit												// (NOTE: 'exit 0' is a command that exits to the next level up)
	   }													// ('origdta' has already been saved, so drop $exists after restoring it)
 												
	} //endif $exists
	
	
	
	
	
global errloc "wrapper(5.1)"
pause (5.1)


										//		 ****************************************************************************
										// (5.1) Call on '_mkcross' to enumerate all contexts identified by a single variable
										//		 that increases monotonically in increments of a single unit across contexts
										//		 (the final variable we need to include in the working dtaset)
										//		 Also check whether data has Stata missing data codes (>=.)
										//		 ****************************************************************************
		
	  tempvar _ctx_temp										// Variable will hold constant 1 if there is only one context
	  tempvar _temp_ctx										// Variable that _mkcross will fill with values 1 to N of cntxts
	  capture label drop lname								// In case error in prev stackMe command left this trailing
	  local nocntxt = 1										// Flag indicates whether there are multiple contexts or not
	  if "`cmd'"=="gendummies"  local nocntxt = 0			// gendummies treats whole dataset as one context
															// WE ALREADY HAVE A FLAG FOR THIS, SET IN CALLER						***
	  checkvars "`contextvars'"								// Just in case these contain a hyphenated varlist
	  local contextvars = r(checked)
	  local contextvars = subinstr("`contextvars'",".","",.) // Remove any missing variable symbols
	  
	  if "`contextvars'" != "" | "`stackid'" != ""  local nocntxt = 0  // Not nocntxt if either source yields multi-contxts

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
		quietly _mkcross `ctxvars', generate(`_temp_ctx') missing strok labelname(lname)										 //	***
*		****************									// (generally calls for each stack within context - see above)
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
										//		 transferred to this codeblk in a future release of stackMe. The programs 
										// 		 called here are final sources of vars to be kept.
										// 		 Capture otherwise undiagnosed errors in programs called from wrapper
										//		 *****************************************************************************
										
										// *******************************************************************				***********
										// NOTE THAT IN THIS CODEBLK 'keepvars' TEMPORARILY MORPHS INTO 'keep' 	   (look for MORPH HERE)		
										// *******************************************************************				***********
	
	  
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
		   local temp = r(impliedvars)						// (other sources supply 'multivarlst' for other 'cmd's)  ******************
		   if "`temp'"=="."  local temp = ""
		   if "`temp'"!=""  global genstkvars = "`temp'"	// SEEMINGLY EMPTY																***
		   local keep="`keepvars' `temp' `keepimpliedvars'"	// Append impliedvars to keepvars AND SAVE BOTH IN 'keep' HERE MORPH HAPPENS
		   local inputs = "`temp'"
		   local multivarlst = r(reshapeStubs)				// Used in `cmd'P call, feeding 'reshapeStubs' to `cmd'P. ******************
		   local multivarlst = subinstr("`multivarlst'",".","",.) // Remove any missing variable symbols
		   local outcomes = "$genstkvars"					// THIS IS ANOMOLOUS SINCE GENSTACK OUTCOMES ARE VARS THAT WERE STUBS
		} //endif 'cmd'=='genstacks'						// (but wrapper does not know that)
		
		  
		else  {												// Else for the other cmds currently having cmd'O programs
		  local temp = r(keepvars)
		  local temp = subinstr("`temp'",".","",.) 			// Remove any missing variable symbols
															//																*******
		  local keep = "`keepvars' `temp'"					// And from `temp'' to 'keep'							   		OR HERE		
		  if `limitdiag'  local fast = "fast"				// Only relevant to geniimpute; limits per context diagnostics  *******
		}
					
			
	  } //endif 'cmd'== "geniimpute"...						// End of clause determining whether 'cmd'O was called
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
	  } //endelse
	  
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
		checkvars "`keep'"									// Check SMvars if there are any
		if "$SMreport"!="" exit 							// Exit takes us straight back to caller, skipping rest of wrapper
		local keep = r(checked)								// (May include SMitem or S2item generated just above)
	  }
*	  ***********************										
		
	  local keep = subinstr("`keep'",".","",.)				// Drop any missing var indicators put there by 'checkvars'
	
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
																	  
	  if substr("`multivarlst'",-2,2)=="||" {				// See if varlist ends with "||" (dk why this happens)
		local len = strlen(strtrim("`multivarlst'"))
		local multivarlst = strtrim(substr("`multivarlst'",1,`len'-2)) 
	  }														// Strip those pipes if so

	  global multivarlst = "`multivarlst'"					// Make it accessible to caller programs and subprograms
															// (`multivarlst' has list of all varlists including ":" and "||")

															

															
	
*	  ********************									************************************
	  forvalues c = 1/`nc'  {								// Cycle thru successive contexts (`c')
*	  ********************									************************************



	
		local lbl : label lname `c'							// Get label associated by _mkcross with context `c' ('cmd'P 
															// programs can optionally have labelname 'lname' hardwired)
		scalar LBL = "`lbl'"								// (use a scalar so does not get dropped at exit from program)

															
*		********										 	**************************************************************
		preserve  								 		 	// Next 3 codeblks use only working subset of context `c' data
*		********										 	**************************************************************


*		************
		quietly keep if `c'==`_temp_ctx' 							// `tempexp' starts either with 'if' or with 'ifexp &'
*		************									 			// ('ifexp' now executed after saving 'origdta' in blk 4)
				
   
*		******************************************		   		  
		if `limitdiag'>=`c' & "$cmd"!="geniimpute"  {																					 
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

			       if _rc  {										// A non-zero error code can only be due to the 'weight' expression

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
																	// (regular 'genplace' outcomes were generaged in 'genplaceO')
		if  !`skipsave'  {											// ***********************************************************

	
	
	
		
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
				local nnames2 = 0									// Local nnames`nlst' is used to record n of names in appendlst#
			
			} //endif `c'==1
						
			
			else {													// Else `c' indicates context beyond the first (i.e. 'c'>1)
				
			   local thisname = substr("`fullname'",`namloc', .)	// Trailing name of file to hold data generatd for this context
			   local namlen = strlen("`thisname'")					// Get length of string holding 'thisname'
			   if `listlen`nlst''+`namlen' > c(macrolen) {			// If length of resulting list of names would be > c(macrolen)
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
 
	   
*	 *******************
	} //next value (`c')											// Repeat while there are any more contexts to be processed
*	 *******************
		
	
	
	
	

	
	if "`spdtst'"==""  {											// If we are NOT testing speed of simpler code ...
																	// ****************************************************************
global errloc "wrapper(8.1)"										// INCLUDE (8.1) IF MINIMIZNG N OF TIMES EACH CNTXT IS SAVED/USED	***
pause (8.1)															// ****************************************************************

	
										// (8.1) After processng last contxt (codeblk 7-8), post-process outcome data for mergng w orignl
										//	     (saved) data. NOTE THAT THE DATA BEING PROCESSED IS NO LONGER THE WORKING DATA SUBSET
										
										
	  if !`skipsave'  {												// Skip this codeblock if conditions for executing it are not met
																	// (skipped only for genplace cmd with no 'call' option)
																	
		if "`multiCntxt'"!=""  {									// If there ARE multi-contexts (local is not empty) ...
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

												//		******************************************************************************
*  capture noisily {							// (9)  Recover `origdta', then the previous names of variables temporarily renamed to  
												//		avoid naming conflicts; merge new vars, created in `cmd'P, with original data
												//		******************************************************************************
	if !`skipsave'  {										// Skip next codeblk if 'cmd' is 'genplace' without 'call' option

*	  ****************************										
	  quietly use $origdta, clear							// Retrieve original data to merge with new vars in $wraptemp 
*	  ****************************							// (vars built in 'cmd'P from vars in 'multivarlst)
															// If we skipped the saves, above, then we don't make any changes
															// (everything from codeblk 8 onward was just cosmetic in that case)

															


pause (10)	  
	  
*	  *****************	  
	  quietly merge 1:m `origunit' using $wrapbld, nogen update replace
*	  *****************										// Here merge the full working dta file w all cntxts back into `origdta'
															// (bringing with it the prefixed outcome vars built from 'multivarlst'
	  erase $wrapbld
	  
	  

	  

	  
															
*	************											// *************************************************************** 
	if "$exists"!=""  {  									// Got its contents in getprfxdvars <-- isnewvar <-- wrapper(5.1) 
*	************											//   These have names that conflict with those of new outcomes that 
															// will been created in cmd's caller program
															// ***************************************************************
		foreach var  of  varlist $exists  {
			capture drop `var'
		}

	} //endif $exists
	
	if "$busydots"!="" noisily display " "					// Override 'continue' following final busy dot(s)
	




	if "`cmd'"!="genstacks"  {								// Genstacks has its own cleanup codeblocks

*		*******
		cleanUp ,  cmd(`cmd') self(`selfplace') dep(`depvarname') apr(`aprefix') dpr(`dprefix') ipr(`iprefix') mpr(`mprefix')  	   ///
/*		*******/  `boundedvars' ppr(`pprefix') xpr(`xprefix') ypr(`yprefix') sta(`stats') mis(`missing') lim(`limitdiag') `nodiag' ///
				  `roundedvars' `keepmissing' `makemisvar'`proximities' `replace' `noduprefix' `wtprefix' *			 
					 
	}						
 
 
 
	local skipcapture = "skip"								// If execution goes thru this point there was no error in capture blocks
	
 
*  ************
} //endcapture												// Close brace matching the 'capture noisily {' at start of program
*  ***********
 
} //endcapture												// Cluge to prevent 'matching close brace not found'
 
 


pause (11)



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
	  scalar limitdiag = $limitdiag 						// And for $limitdiag
	  scalar SMreport = "initialized"						// Need this work-around in case "$SMreport was never set non-empty
	  scalar SMreport = "$SMreport"							// (an undefined scalar cannot be defined by assigning it an empty global)
	  macro drop _all										// Drops above globals (along with many others and all locals) before exit
	
	  global origdta = origdta								// Global origdta is needed by caller programs, re-entered on 'end' below
	  global multivarlst = multivarlst						// Ditto for $multivarlst (used in many caller programs)
	  global limitdiag = limitdiag							// And for limitdiag (used ubiquitously)
	  if SMreport !="initialized" global SMreport =SMreport // And $SMreport, if its scalar's "initialized" flag has been replaced
	
	  scalar drop _all										// Drop all scalars before exit
	
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
* checkvars				Wrapper(2.2) 					Alternative for unab that handles mixed hyphenated and abbreviated varnames
*													 Note: "text" [or "noexit"] prevents call on 'errexit' from 'chackvars' on error] 
* cleanUp				Wrapper(10) except genstacks	Cleans up outcome data after processing (labeling, rounding, prefixing, etc.)
* dispLine				Wrapper, showdiag2, others		Displays text in Results window with optimized line-breaks
* errexit				Everywhere						Displays error msg in 'note' window; optionally also in Results window 
*													 Note: arg "msg" | opts , msg(required) rc() display(reqrd to display msg)
* getprfxdvars			Wrapper(5.1); isnewvar			Initialize outcome variables as required by each command
*													 Note: outcomes, options lets program identify optioned outcome prefix-strings
* getwtvars				Wrapper(2)						Establish weight string for each nvarlst in a multivarlist
* isnewvar				Wrapper(various)				See if vars [w optioned prefix-string] already exist
* showdiag1				Wrapper(6)						Store diagnostic stats before calling 'cmd'P
* showdiag2				Wrapper(7)						Display diagnostic stats after return from 'cmd'P
* subinoptarg			unsure if called at all			Shorthand way to replace argument within option string
* stubsImpliedByVars	genstacksO (twice)				Name says it
* varsImpliedByStubs	genstacksO, cleanup			Name says it
*
********************************************************************************************************************************




capture program drop checkSM

program define checkSM, rclass						// Checks validity of stackMe special names (SM names) and their linkages

																  // (Those names may match already extant varnames)
global errloc "checkSM"

   args check noexit											  // Argument 'check' contains list of non-'unab'ed variables	
																  // Arg 'noexit' forces return to caller on error
   capture noisily {
   	
	  checkvars "`check'"										  // Redundant when called from wrapper; maybe not always so	***
	  if "$SMreport"!=""  exit									  // Non-empty $SMreport flags return from 'errexit', so exit
	  
	  local allSMvars = "SM*"									  // Get a list of all vars starting with SM (used at end)
	  capture unab allSMvars : `allSMvars'
	  if _rc  local allSMvars = ""
	  
	  local gotSMvars = ""										  // List of extant SM/S2 items
	  local SMvars = ""											  // List of SMitem or S2item included  in 'check'
	  local SMerrs = ""											  // SM/S2 items with no link to existing var ditto
	  local SMbadlnk = ""										  // SM/S2 items whose link does not exist ditto
	  local errlst = ""										  	  // List of broken links (linked vars that don't exist)
		
	  if strpos("`check'", "SMitem")>0  local SMvars = "SMitem"   // Check the same vars as checked above (inputs + outcomes)
	  if strpos("`check'", "S2item")>0  local SMvars = "`SMvars' S2item" // (to see if user included SMitem or S2item)

	  if "`SMvars'"!=""  {										  // If there are any SMvars
	  
		foreach var  of  local SMvars  {						  // Cycle thru the (up to) 2 vars in 'SMvars'
	  	
		   local `var' = "`_dta[`var']'" 	  					  // Retrieve associated linkage variable from characteristc
		   
		} //next 'var'
		   
		if "`SMitem'" ==""  local SMerrs = "`SMerrs' `var'"		  // If SMitem isnt linked, extend list of unlinked SMvars
		else  local gotSMvars = "`gotSMvars' `var'"		  		  // Else extend list of linked SMvars
		   
		if "`S2item'"=="" local SMerrs = "`SMerrs' `var'"		  // If S2item isnt linked, extend list of unlinked SMvars
		else  local gotSMvars = "`gotSMvars' `var'"		  		  // Else extend list of linked SMvars
			
		
		if "`SMerrs'"!=""  {									  // If there are any unlinked SMvars
		
		   dispLine "SMvar(s) without active link(s) to (existing) variable(s): `SMerrs'" "aserr"
*					12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   if wordcount("`SMerrs'") == 1  errexit "stackMe quasi-var `SMerrs' has no active link to an existing variable"
		   else  dispLine "stackMe special vars with no active links to existing vars: `SMerrs'" "aserr"
		   errexit, msg("See displayed list of special vars without active links to existing vars")
		   exit
		}														  // Else we have SMvar(s) with links to exsting
		else  {
		   	if wordcount("`SMerrs'")==1  {
				errexit "stackMe quasi-var '`SMerrs'' has no active link to existing var"
				exit
			}
		   	else  dispLine "stackMe quasi-vars with no active links to existing vars: `SMerrs'" "aserr"
			errexit, msg("stackMe quasi-vars have no active links to existing vars – see displayed list")
			exit												  // 'errexit' w options & w'out 'display' suppresses console displ
		}														  // 'else' only executed if wordcount>1
		   
																  // If we reach this point we have links to check
		checkvars "`gotSMvars'" "noexit"					  	  // "'noexit' causes return after checkvars error"
		local checkvars = subinstr("`checkvars'",".","",.) 		  // Remove any missing variable symbols

		local gotSMvars = r(checked)							  // Returns all valid vars
		local gotSMvars = subinstr("`gotSMvars'",".","",.) 		  // Remove any missing variable symbols

		foreach var  of  local gotSMvars	{					  // Cycle thru (up to) 2 vars in 'gotSMvars'
		   capture unab var : `var'				  			  	  // See if these linked vars exist
		   if _rc  {											  // If link does not access an existing variable
			  local SMbadlnk = "`SMbadlnk' `var'"			  	  // Add that quasi-var to 'SMbadlnk'
		   }
		} //next 'var'
		   
		if "`SMbadlnk'"!="" {								      // If 'SMnolnk' is not empty
		   errexit "Quasi-vars with broken links (linked vars don't exist): `SMbadlnk'"
		   exit
		}													  	  // 'errexit' is a subprogram listed later in this ado file
	  }
		
	  if "`gotSMvars'"!=""  {
	  	if "`allSMvars'"!=""  {
		  foreach v  of  local gotSMvars  {
			 local allSMvars = subinstr("`allSMvars'","`v'","",.) // Replace each `v' of gotSMvars found in 'allSMvars' with ""
		  }														  // (removes from allSMvars any SMvars identified specifically)
		}
	  }

	  global cmdSMvars = "`allSMvars'"					  		  // Remaining SMvars should be command-specific  
																  // (but perhaps not specific to the current command!)				***
	  return local gotSMvars `gotSMvars'	  					  // List of specified SMvars found above
	  
	  local skipcapture = "skip"
	  
   } //endif 'capture'
   
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in checkSM"
      exit
   }
														
end checkSM



********************************************************************************************************************************



capture program drop checkvars
		
program checkvars, rclass						// Checks for valid input/outcome vars. Partially overcomes intermittant
												//  error when unab is presented with a hyphentated list of varnames
												// (with hyphentd AND non-hyphenated it can wrongly send non-zero return code)
												// ("partially" because 'unab' exits on first bad varname it finds, whereas
												//	the whole point of this subprogram is to build a list of all bad varnames)
															// (check those names in case they match already extant varnames)
global errloc "checkvars"

	args check noexit											// Argument 'check' has list of non-'unab'ed variables	
																// (may include hyphenated varlist(s))
*	****************																// (returns unabbreviated un-hyphenated vars in r(check))
	capture noisily {
*	****************
																
		local uniqvars : list uniq check						// Remove any duplicates; then check validity
																//				   			of each var and hyphenated varlist 
		local errlst = ""										// List of invalid vars and invalid hyphenatd varlsts
		
		local check = strtrim(stritrim("`uniqvars'"))			// Eliminate extra blanks around or within 'check'
		
		if strpos("`check'","-")==0  {							// If there are no hyphenated varlists
		  foreach var  of  local check  {						// Cycle thru un-hyphenated vars in varlist
			capture unab var : `var'							// If 0 not returned variable does not exist
			if _rc  {
				local errlst = "`errlst' `var'"					// So add that invalid var to 'errlst'
				local rc = _rc									// And store the return code in local rc
			}
			else local checked = "`checked' `var'"				// Else add that valid `var' to 'checked'
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
			   foreach var  of  local pret1  {					// And evaluate each one
			   	  capture unab var : `var'						// If 0 not returned...
				  if _rc  local errlst = "`errlst' `var'"		// Add any invalid varname to 'errlst'
				  else  local checked = "`checked' `var'"		// Else add the valid varname to `checked'
			   }
			}													// 'test3' will be string "'test1'-'test2'" inclusive
			local t3len = strlen("`test1'")+strlen("`test2'")+1	// Get full length of string 'test1' to end of `test2'
			local test3 = substr("`chklist'",`t1loc',`t3len') 	// String them together as when embedded in 'chklist'
			foreach var  of  local test3  {						// Test3 starts w 'test1' & ends w end of word after "-"
			  capture unab var : `var'							// Evaluate each oone
			  if _rc  {											// If 0 not returned 'var' is not a valid variable
			    local errlst = "`errlst' `var'"					// Add this var to cumulating list of errors
				local rc = _rc
			  }
			  else  local checked = "`checked' `var'"			// Else add it to 'checked'
			} //next 'var'
			
			local chklist = substr("`chklist'",`t1loc'+`t3len'+1,.) // Strip all up to end of 'test3' from head of chklist
			
*			if "`errlst'"!="" & "`errlst'"!="." &  strpos("`chklist'","-")>0  continue, break	
																// If there is ANOTHER "-", skip rest of while 
																// (SEE IF STILL WORKS WITHOUT THIS SKIP)
	
			if "`chklist'"!="" {								// See if there are more vars in 'chklist'
			   foreach var  of  local chklist  {					// Check that each of them is valid
			   	 capture unab var : `var'
				 if _rc  {
				 	global SMrc = _rc
				 	local errlst = "`errlst' `var'"				// If 0 not returned add any invalid vars to 'errlst'
				 }
				 else  {										// THESE BRACES ARE NEEDED, OR STATA DISREGARDS 'else'			***
				 	local checked = "`checked' `var'"			// Else add to list of checked vars
				 }
			  } //next var
			} //endif
			
		  } //next hyphen										// See if there are any more hyphens
		  
		} //endelse												// End of codeblock dealing with hyphated varlist(s)
		
								
		if "`errlst'"!="" & "`errlst'"!="."  {					// If any bad varnames were identified ...
		  dispLine "Invalid variable name(s): `errlst'"  "aserr"
		  if "`noexit'"==""  {
		  	 errexit, msg("Invalid variable name(s) `errlst'")
			 exit												// 'errexit' w opts & w'out 'display' supporesses results display
		  }
		}														// (after displaying above msg)
		
		return local checked "`checked'"						// Return unabbreviated un-hyphenated vars in r(checked)
		return local errlst "`errlst'"							// Return list of unconfirmed vars
		
		local skipcapture = "skip"

		
*	 *************	
	} //endcapture
*	 *************
	
    if _rc & "`skipcapture'"==""  {
   	   errexit "Error in checkvars"
       exit
    }
														
	

end checkvars



********************************************************************************************************************************



	
capture program drop cleanUp			// Program that performs the final tidying of outcome variables: labeling the variables
										// and (for gendummies) values; enumerate vars with all-missing values, to be skipped;
										// create or update SMmisval and SMplugmisval variables; round and bound vars as optioned;
										// revise or alter prefix strings as optioned
	
program define cleanUp
	

	

* *****************
  capture noisily {										// Open brace for codeblocks where errors will be captured, to be
* *****************										//  processed following the matching close brace at and of program


* *****************										// 2nd occurrance of this command avoids  "} is not a valid command name"
* capture noisily {
* *****************	

										
global errloc "cleanUp(10)"				// This global keeps track of currently executing codeblock to help diagnose program errors
										// (trailing number comes from codeblock in stackmeWrapper where these codeblks originated)

pause cleanUp(10)


	if "$namechange" !=""	{								// If, before merging with 'origdta' we changed the names of certain vars
															// (done in subprogram 'getprfxdvara'<-'wrapper to avoid merge conflicts)
		foreach var  of  global namechange  {				// HERE WE UNDO THOSE NAME CHANGES
															
		   capture confirm variable `var'					// DK WHY WE NEED THIS CHECK												***
		   if _rc ==0  {									// If return code indicates this is an existing variable
		   
		   	  local tempname = strlower(substr("`var'",1,1)) + substr("`var'",2,.)  // Upper case 1st char allowed co-existence
			  rename `var' `tempname'						// Make strlower first char of existing potentially conflicted name
			  global namechange = "$namechange `tempname'"	// (name change reverses shange made in getprfxdvars <- wrapper(10))
		   }
															// GLOBAL 'namechange' WAS GIVEN THE NAMES OF RENAMEDVARS  
		}
		
    } // endif $namechange


	
	
	syntax , [ cmd(str) SELfplace(name) DEPvarname(name) APRefix(str) DPRefix(str) IPRefix(str) MPRefix(str) PPRefix(str) ]	///
			 [ XPRefix(str) YPRefix(str) MISsing(str) LIMitdiag(integer -1) PROximities NODiag ROUnd BOUnd KEEpmissing ] 	///
			 [ MULtivariate MAKemisvars REPlace NOReplace NODuprefix WTPrefix * ]	

										
										
										
										// (10) Reduce all prefix-options to single-char (users can employ either); then label
										//		vars appropriately according to input and outcome characteristics

	local ic = substr("$cmd",4,1)							// Get initial (post-"gen") char of commandname
	if "`cmd'"=="gendummies"  local ic = "du"				// (1st two cars for gendummies and genmeanstats)
	if "`noreplace'"!=""  local replace = "replace"			// Actual option seen by user is 'noreplace'
	
	local prx = 0
	
	if "`proximities'"!=""  {								// This codeblk applies only to 'gendist'
		
	   local prx = 1										// Proximities will be generated after next 'foreach var'
	   
	   if "`replace'"!=""  {
			noisily display "Will calculate proximities as optioned; dropping distances per 'replace' option"
*					 		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
	   }
	   else noisily display "Will calculate proximities as optd; distances kept since 'replace' was not optd"

	} //endif 'proximities'

	else  {													// Else proximities are not being calculated
		if "`replace'"!=""  noisily display "Dropping relevant input variables per 'replace' option"
	}														// Applies to all but 'gendist' command
	  
	local miss = "`missing'" 								// (missingness is tracked for gendist and geniimpute)
	if ("`miss'"=="") local miss = "all"					// Default if 'missing' option was not used
	if "`miss'"=="mean" local miss = "all"					// Permit legacy keyword "mean" for what is now "all"
	if "`miss'"!="dif2" local miss = substr("`miss'",1,3)	// Keep 4 chars if those are "dif2", else just 3 chars
	if "`miss'"=="di2"	local miss = "dif2"					// (in case user thinks there is a 3-char minimum)
	if "`miss'"=="dif" local miss = "diff"					// (ditto)

	if "`cmd'"=="geniimpute" local miss = "imputed"			// (other commands do not have an m_prefixed outcome var)
	if "`cmd'"=="gendummies"  local miss = "stub"
	if "`cmd'"=="genyhats" local miss = "predicted"			// (these other commands use `miss' to customize their var labels)
	
*	scalar MISS = "`miss'"									// (ATTEMPT TO OVERCOME PROBLEM OF `miss' LOSING ITS CONTENTS)		***

				
	local non2missing = ""									// List of vars present across all varlists (for diagnostic)
	local skipvars = ""										// List of vars missing for all contexts, cumulates across varlists
															// (needed to eliminate all-missing variables from the data)
															
	local nvarlsts = NVARLSTS								// Get N of varlists from scalar NVARLSTS

	forvalues nvl = 1/`nvarlsts'  {							// Cycle thru all varlists
	
	   local vars = VARLISTS`nvl'							// Retrieve each varlist from scalar VARLISTS`nvarlst
	   local prfxvars = PRFXVARS`nvl'						// Retrieve any var prefixes
	   local strprfx = PRFXSTRS`nvl'						// And any string prefixes
															// (two above were already copied into options in wrapper(3) if relevant)
	   unab varlist : `vars'								// Unabbreviate and expand varlist 'vars'
			
	   if "`cmd'"=="genyhats"  {							// If this is a yhats command
	   	  if "`prfxvars'"!="" & "`prfxvars'"!="." {			// If there is a prefix var (genyhats would have only one)
		  	 local multivariate = "yes" 					// This is a multivariate analysis even if that was not optioned
			 local depvarname = "`prfxvars'"				// Overwrite any optioned depvarname with prefix var
		     if "`multivariate'"!=""  {						// If `multivariate' was either optioned or signalled by `prfxvars'
			    local lbl = "Yhat for `depvarname' regressed on `varlist'"
				if strlen("`lbl'")>78 local lbl = substr(,1,78)+".."
			 } //endif
			 label var d_`depvar' "`lbl'"					// The only label for a multivariate analysis
		  } //endif `prfxvars'
*		  continue											// So continue with the next `nvl'
	   } //endif `'cmd'==`genyhats'

	  	  
	   global nonmissing = ""								// Will hold list of vars present for at least 1 contxt
															// (needed for diagnostics)
															
	   foreach var  of  local varlist  {					// This varlist is still the original user-typed varlist
															// (though for genmeanstats it is a list of string prefixes)
		  if strpos("`skipvars'","`var'")  continue			// If `var' is included in list of vars to skip, continue with next var
															// If this is first var, continue happens after 'count' below
		  qui count if !missing(`var')						// These counts are for the entire dataset
		  if r(N)==0  {										// (unlike the counts by context made in 'stackmeWrapper')
			local skipvars = "`skipvars' `var' "			// 'skipvars' holds vars that have no obs in any context
			continue										// Continue to next var if all-missing
		  }
		  
		  else  {											// Next line needed for diagnostics report
		  
		 	global nonmissing = "$nonmissing `var'"			// Else there are non-missing observations in this varlist

			if `prx'  {										// If proximities were optioned on a gendist command (DONT CONFUSE W 'pfx')
			
			   tempvar max				
			   qui egen `max' = max(`var') if `var'<.		// Get max value of `var' over whole dataset
			   
			   if `limitdiag'  noisily display "`var' proximities over all contexts " _continue
*												12345678901234567890123456789012345678901234567890123456789012345678901234567890
			   if `limitdiag' gen x_`var' = `max' - d_`var'	// Invert the distance measures with missing data diagnostic
			   else  quietly gen x_`var' = `max' - d_`var'	// Ditto without missing data diagnostic if 'limitdiag'==0
			   
			} //endif `prx'
			
			capture local lbl : variable label `var'		// Get existing var label, if any
			
			if _rc  {										// If no such label
			
				if "`cmd'"!="genmeanstats" & "`cmd'"!="gendummies"  local lbl = "battery member"
			} 												// If _rc not zero there was no lable so substitute above text
			
			else  {											// Else there is a label; see if it ends with numeric value
			
			   while real(substr("`lbl'",-1,1))!=.  {		// If converstion to real not missing, last char is a number
				  local lbl = substr("`lbl'",1,strlen("`lbl'")-1) // (so remove that char from end of string and repeat)
			   } //next while								// Hopefully string now ends in generic name, not specific value
			   local lbl = strrtrim("`lbl'") + ": " 		// Strip any traling blanks from 'lbl' and append a colon
			   
			} //endelse
			
*			local miss = MISS								// ATTEMPTED RETRIEVAL OF `miss' whose content was somehow lost			***
			
			if "`cmd'"=="gendist"  {						// Now consider cmds that are NOT genmeanstats or gendummies
				
				local lbl1 = substr("Dist from `selfplace' to `miss'-assessed `var':`lbl'",1,78) + ".."
*					 		  		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				label var d_`var' "`lbl1'"					 // Include as much of label as fits in 78 columns
				
			}
							
			if `prx'  {
				local lbl2 = "Proximity of `selfplace' to `miss'-assessed `var': `lbl'" 		  // (this would be a gendist label)
				if strlen("`lbl2'")>78  local lbl2 = substr("`lbl2'",1,78) + ".."	  // (of no more than 78 chars)
				label var x_`var' "`lbl2'"
			}

															// Else cmd is gendu genii genme genpl or genyh
			
*			if "`cmd'"=="gendummies" label var `du_'`var' 	// THIS IS STILL DONE IN 'gendummies' (REMAINING CODE STILL TO BE MOVED)	***

			if "`cmd'"=="geniimpute"  {
			  	  local lbl1 = "Outcome values imputed from "+stritrim(subinstr("`varlist'","`var'","",1)) + " `additional'"
				  if strlen("`lbl1'")>78  local lbl1 = substr("`lbl1'",1,78) + ".." // Include as many names as fit in 78 cols
*				  label var i_`var' "`lbl1'"
			} //endif
			   
			   
			if "`cmd'"=="genmeanstats"  {
				
				  local n = 0
				  foreach stat  of  global statlist  {		// Set in genmeanstatsP
				  
					 local n = `n' + 1
					 local pfx = word("$pfxlist",`n')		// Set in genmeanstatsP

					 local lbl1 = strupper(substr("`stat'",1,1)) + substr("`stat'",3,.)					 
					 if `lbl1'=="n"  local `lbl1'" = "N of observations for var `var': `lbl'" // (`lbl' is var label set above)
					 if `lbl1'=="suofwts"  local lbl1 = "Sum of weights for var `var': `lbl'" // (`lbl' is var label set above)
					 if strlen("`lbl1'")>78  {
					 	local lbl1 = substr("`lbl1'",1,78) + ".." // (of no more than 78 chars)
					 }
					
					label var `pfx'`var' `lbl1' 
					 
				  } //next 'stat'

			} //endif 'cmd'=="genmeanstats"
			   
			   
			if "`cmd'"=="genyhats" & "`multivariate'"=="" {	// If this is a bivariate genyhats analysis

			   local lbl2 = substr("Outcome y-hat for `var' regressed on by `depvarname'",1,78) + ".."
*					 		  	    12345678901234567890123456789012345678901234567890123456789012345678901234567890
			   label var i_`var' "`lbl2'"
			}												// If multivariate, the d_`var' was labeled before 'foreach'
			
			
															// MOVE ON TO ADDITIONAL OUTCOMES PRODUCED BY SOME COMMANDS
															
			if "`cmd'"=="gendist" | "`cmd'"=="geniimpute" {	// These two commands have an m_prefixed outcome variable
				label var m_`var' "Whether variable `var' was originally missing" 				
			}												// So label it
			
			
			if "`cmd'"=="gendist"  {									
				local temp = substr("`miss'-assessed plugging values for var `var':`lbl'",1,78)+".."
				label var p_`var' "`temp'"
			}
			
						
			if "`cmd'"=="genplace"  {
				
			   display as error "labeling not yet implimented for genplace"	
															// WILL BE FILLED IN WHEN CODE FOR CMD genplace IS FINALIZED				***
			}
			
		  } //endelse 'r(N)'								// (corresponding 'if' is right after 'foreach var')
			
	   } //next 'var'						
	   
	   local non2missing = "`non2missing' $nonmissing"		// Needed for diagnostic report

    } //next 'nvl'											// Repeat for next varlist, if any
	
	
	
	
global errloc "cleanUp(10.1)"

pause cleanUp(10.1)




										// (10.1)  Create counts of nonmissing vars vs vars to be skipped
	
	
	  local nvars : list sizeof non2missing					 // `non2missing' relates to vars across all varlists
	  local first = word("`non2missing'",1)
	  local last = word("`non2missing'",`nvars')
	
	  foreach SMvar  in  SM`ic'misCount SM`ic'misPlugCount { // Cycle thru the two summary measures
															 // (using initial char (`ic') to differentiate commands)
		if "`SMvar'"=="SM`ic'misCount" local txt ="original" // Set text to be included in var label for input var
		else {												 // else set text for outcome var
			if "`ic'"=="d" local txt = "mean-plugged"		 // (i.e. mean-plugged, imputed or y-hatted)
			if "`ic'"=="i" local txt = "imputed"
			if "`ic'"=="y" local txt = "y-hat"
			if "`ic'"=="du" local txt = "stub"				 // (will overwrite the txt established when "d" was matched)
			if "`cmd'"=="genmeanstats" local txt = "stat"
		}
		
		capture confirm variable `SMvar'					 // See if variable exists from previous run
		if _rc==0  {										 // If that var already exists THIS ALREADY DONE EARLIER?					***
			local msg = "Var `SMvar' already exists (left by some earlier stackMe command); replace?"
*					       12345678901234567890123456789012345678901234567890123456789012345678901234567890
		    if strlen("`msg'")>80 local msg = "Var `SMvar' exists (left by earlier stackMe command); replace?"
			display as error "`msg'{txt}"					 // If needed, shorten 'msg' to fit in 80 columns
			capture window stopbox rusure ///
			"Var `SMvar' already exists (left by some earlier `cmd' command); drop it?"
			if _rc  {
			   errexit, msg("Lacking permission to drop variable `SMvar'")	// _rc was non-zero so user is not 'OK'
			   exit
			}
			else  capture drop `SMvar'						// Else user clicked 'OK'
				
		} //endif _rc										// Either way 'egen' the var now named by local SMvar
		
		quietly egen `SMvar' = rowmiss(`non2missing')		// Count of vars not all-missing for any varlist

		if "`first'"=="`last'" capture label var `SMvar' "N of missing values for `txt' var from `first'"
		else {
			capture label var `SMvar' "N of missing values for `txt' vars (`first'..`last')"
		}													// Contents of `txt' local was set above
	
	  } //next SMvar
	
	  if $limitdiag noisily display " "						// Display a blank line to terminate per context diagnostics



	
	
	
global errloc "cleanUp(10.2)"

pause cleanUp(10.2)



										// (10.2) Round outcomes if optioned
												  
	
	  if "`round'"!=""	 {									// If 'round' was optioned
	   
		if `limitdiag'  noisily display "Rounding outcome variables as optioned"

		forvalues nvl = 1/`nvarlsts'  {						// Cycle thru all varlists (derived from scalar VARLISTS in codeblk 10)
	
			foreach var  of  local varlist  {				// Cycle thru all outcome vars for all varlists
	   
				if strpos("`skipvars'","`var'") continue	// Skip any that are all missing in all contexts

				qui sum `var'
				local max = r(max)
				if "`cmd'"=="gendist'" | ("`cmd'"=="genyhats" & "`multivariate'"!="")  {
					qui replace d_`var' = round(d_`var', .1) if `max'<=1
					qui replace d_`var' = round(d_`var') if `max'>1
				}
															// If max value of var is >1, round to nearest integer
				if "`cmd'"=="geniimpute" | ("`cmd'"=="genyhats" & "`multivariate'"=="")  {
				   qui replace i_`var' = round(i_`var', .1) if `max'<=1
				   qui replace i_`var' = round(i_`var') if `max'>1
				}

				if `prx'  {									// `prx' is set by a gendist option
				   qui replace x_`var' = round(x_`var', .1) if `max'<=1
				   qui replace x_`var' = round(x_`var') if `max'>1
				}
				
		    } //next `var'
			  
		} //next 'nvl'
	
	  } //endif 'round'   			
		


		
	
	
global errloc "cleanUp(10.3)"

pause cleanUp(10.3)
pause off


											// (10.3)	Alter variable prefix strings if optioned (vars were labled in blk 10)
											//			This is where variables are renamed to include respective cmd prefix chars
	
	if "`cmd'"=="gendist"  local optnames     = "dprefix mprefix pprefix xprefix" // (aprefix us taken care of below)
	if "`cmd'"=="gendummies"  local optnames  = "duprefix"	//
	if "`cmd'"=="geniimpute" local optnames   = "iprefix mprefix"
	if "`cmd'"=="genmeanstats" local optnames = "N meaprefix medprefix modprefix sdprefix miprefix maprefix skprefix kuprefix " ///
											  + "suprefix swprefix"
	if "`cmd'"=="genplace"  local optnames    = "iprefix mprefix pprefix" 
	if "`cmd'"=="genyhats" local optnames     = "iprefix" 	// (dprefix is handled separately, right after 'forvalues')
															// Above are the specific options that may be user-invoked for each cmd	

	local ic = substr("`cmd'",4,1)							// Get identifying character (ic – eg d for gendist) of current command
															// (We deal with 'gendu' and 'genme' – with 2-char 'ic's – below)	
	if "`cmd'"=="gendummies" | "`cmd'"=="genmeanstats"  {	// 'gendummies' and 'genmeanstats' have non-standrd `ic's (initl chars)
	   local ic = substr("`cmd'",4,2)						// (for all other cmds the `ic' is the 1st character following "gen")
	}

	
	forvalues nvl = 1/`nvarlsts'  {							// Cycle thru all varlists 
	
	   if "`cmd'"=="genyhats" & "`multivariate'"!="" {		// If this was a multivariate genyhats command..
	   	  local opfx = "d"
		  if "`dprefix'"!=""  {
		  	 if substr("`dprefix'",-1,1)=="_" local opfx = substr("`opfx'",1,strlen("`opfx'")-1)
		  }
		  local aprx = "`aprefix'"
		  if "`aprefix'"!=""  {
		  	 if substr("`aprefix'",-1,1)=="_" local aopfx = substr("`apfx'",1,strlen("`apfx'")-1)
		  }
		  rename d_`depvarname' y`opfx'`apfx'_`depvarname' // Strip any trailing "_" and rename
		  continue											 // Continue with next `nvl'
		  
	   }													 // Bivariate genyhats are handled below
	   
		
	   local varlist = VARLISTS`nvl'						// Same scalar as used in codeblk cleanup(10)
	   unab vars : `varlist'								// Call on 'unab' SHOULD BE REDUNDANT									***
	

	   foreach v  of  local vars  {							// Cycle thru all outcome vars for each varlist
	   
		  if strpos("`skipvars'","`v'")  continue			// if var `v' is in list of vars to be skipped, continue w next var
		  
		  local nprfx = 0									// Counter will synchronize  posn in `pfrxlist' with posn in `optnames'
															// (for the benefit of 'genmeanstats')
		  foreach opt  of  local optnames  {				// Go thru optionable string prefixes for current cmd (usng v1 naming)
															// ('opnames' names are specific to the current command see above)
															
			 if "`cmd'"!="genmeanstats" | "``opt''"!=""  {  // Execute this codeblks if not 'genme' or current `opt' was user-optiond
			 
				local vpfx = substr("`opt'",1,1)			// By default "`opt'",1,1 has input prefix for 'cmd'P (excpt gendu genme)
				local pfxpfx = "`vpfx'"						// This local name is unspecific about whether it includes `aprefix'
	
				if "``opt''"!=""  {							// If `optname', specific to each default prefix, was optioned...
															// (then it points to what was optioned, so ``opt'' is not empty)
				   local opfx = "``opt''"					// This is the prefix (eg. `dprefix') optioned by the user, if not empty
															// Use double-quotes to access the string that the user supplied)														
				   if substr("`opfx'",-1,1)=="_" local opfx = substr("`opfx'",1,strlen("`opfx'")-1)
															// (if the user-optioned string includes a trailing "_", remove it)
				   local pfxpfx = "`opfx'"					// This local now contains just the optioned the user-optioned string
				   local optfx = ""							// Empty this local in case next opt is empty
				
				} //endif ``opt''								

				if "`aprefix'"!=""  {						// If `aprefix' was user-optioned
				   if substr("`aprefix'",-1,1)=="_"  local aprefix = substr("`aprefix'",1,strlen("`aprefix'")-1) // Remove "_" if any
				   local pfxpfx = "`pfxpfx'`aprefix'"		// Ambiguously-named local now has both (prhps optd) `opfx' & `aprefix'
				}											// (this is for the general case; 'genme' & 'gendu' are different)
				
			 } //endif `cmd'"!="genme"...
			 

*			 ****************************			 
			 if "`cmd'"=="genmeanstats"  {					// Next, deal with the two special cases ...
*			 ****************************		 	
				
				local nprfx = `nprfx' + 1					// Increment the link to global optnames
				local prfx = word("$optnames",`nprfx')		// Global set in genmeanstatsP (contains outcome label names)
															// (two of which will be corrected just below to become prefixes)
				if "`prfx'"=="sofwts" local prefx = "sw" 	// If optioned stats include sum of weights, correct the prefix
				if "`prfx'"=="n"  local prefx = "N"			// If optioned stats include "n", make that "N"
															// (CAREFULLY DISTINGUISH BETWEEN `prfx' AND `prefx')
				
				local pfxaprefix = "`ic'`aprefix'"			// (this is used as an outcome var prefix; it is not `pfxaprfx')
															// (`ic' was abstracted from 'genmeanstats' before `forvalues' above)
*				******************  ***************** ***************// If this `prefx' (stat) was optioned, rename corrspdng var
				if strpos("`stats'","prefx")  rename `prefx'_`v'  `pfxaprefix'`_v' 
*				******************  ***************** *************** // MUST DISTINGUISH BETWEEN `pfxaprefix' AND `pfxaprfx'
															// (Only `aprefix' can affect the name of a 'genme' outcome variable)
															// (otherwise that outcome has the same name as the input)
															
			 } //endif `cmd'=="genmeanstats"

			 
*			 ******			 
			 else  {										// Else, for any other cmd (i.e. not 'genmeanstats' dealt with above)...
*			 ******											// (within this 'else' clause, `pfx' is substr("`opt'",1,1) from earlier)
*				**************************
			    if "`cmd'"=="gendummies"  {					// Gendu is the one command that does not use an input varname prefix
*				**************************								
*				   rename `v'#  `ic'`optapfx'_`v'#			// THIS SYNTAX DOES NOT WORK, DESPITE INFO IN help rename group			***

				   quietly levelsof `v', local(V)
				   foreach val of local V  {
*				   	  ***************  **********************
					  capture rename `v'`val'  `ic'_`v'`val' // 'capture' CAPTURE 'COS levelsof CAN PRODUCE AN EXTRA LVL !			***
					  ***************  **********************
				   } //next `val'
				   
				} //endif "`cmd'"=="gendummies"				
				
				
*				******	    *******************************
				else  {	 // Else, for all other commands...
*				******	    *******************************
																														
*				   ****************  *****************		// Use input prefix (from start of `opt' loop) for `v'
				   rename `vpfx'_`v' `ic'`pfxpfx'_`v' 		// For most commands the outcome prefix starts with `ic'
*				   ****************  *****************		// (and we append the original `pfxpfx' – not the later `pfxaprefix')
															// (if aprefix was not optnd outcome prefix is "`ic'_" – see above)

				} //endelse 'cmd'						
				
			 } //endelse
			 local pfxpfx = ""								// Empty this in case next var has no user-optioned prefix
				 
		  } //next 'opt' 
		  
	   } //next 'v'
	   	
	} //next 'nvl'
	
	
	capture drop p_*  									 	// These will be vars with missing obs for all cases
	capture drop m_*
	capture drop d_*
	capture drop x_*
	capture drop i_*

	
  
    local skipcapture = "skip"							 // In case there is a trailing non-zero return code
														 // (if this cmd executes there was no error between the capture braces
	
	
	
* *************											    **********************************************************************
} //endcapture											 // Close brace enclosing code, back to top, whose errors will be captured
* *************											 // (any error found there will cause execution to skip to following code)
*														    **********************************************************************
	
	
	
  if _rc & "`skipcapture'"==""  {
  	
	errexit "Error in $errloc"
	
  }
  
  
  
end cleanUp
	

	
************************************************************************************************************************************



capture program drop dispLine

program define dispLine							// This program was written to overcome an apparent error when Stata refused to
												//   display text 'display'ed by a subprogram called from within capture braces. 
args msg aserr									// A better solution was to put the 'display' command itself within capture braces, 
												//   but this subprogram then became a means of displaying text with >80 colums
												
*global errloc "dispLine"						// COMMENTED OUT BECAUSE IT COULD BE MISLEADING IF DISPLINE WAS CALLED FROM errexit

if "$busydots"!=""  noisily display " "						// If previous display ended with _continue, display a blank line



capture noisily {

  while strlen("`msg'") > 80 {								// While 'msg' fills more than an 80-column display line

	local lastspace = strrpos(substr("`msg'",1,81)," ")		// Find last blank in 81-char substring 
	local line = substr("`msg'",1,`lastspace')				// (could be #81, in which case we would have an 80-column line)
	if "`aserr'"!=""  noisily display "{err}`line'{txt}"	// Display this line 'as error' if optioned
	else  noisily display "{txt}`line'"						// Else display it noisily
	
	local msg = substr("`msg'", `lastspace'+1, .)			// Trim off what was displayed, plus final " "

  } //endwhile 'msg'>80
  
  if "`msg'"!=""  {											// If there are any characters left un-displayed
	if "`aserr'"!="" noisily display "{err}`msg'{txt}"		// Display final (or only) line as error if optioned
	else noisily display "{txt}`msg'"						// Else display it noisily 
  }
  
  local skipcapture = "skip"

} //endcapture




   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit
   }
														


end dispLine



*****************************************************************************************************************************************



capture program drop errexit

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

* DON'T SET $errloc								// WOULD BE MISLEADING! (We want to retain location from which 'errexit' was called)


if "$SMreport"!=""  exit						// If the error was previously reported then the call on this program was redundant

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
       syntax , [ MSG(string) rc(string) DISplay *]
	   if "`display'"!="" scalar display = "display"
	   else scalar display = ""					// Uninitialized scalar is not empty, like an unitialized macro, and we want this empty
    }											// (optional `rc' is Stata return code – RC – or string that caused the error)
	
	else  {										// Else there is no comma, so up to two arguments were sent as 'arg's
	   args msg rc								// First arg is `msg' to display; 2nd is optional Stata return code, if numeric
	   scalar display = "display"				// (there is no comma, so 'msg' argument is for stopbox AND for Results window)
	}											//  Optional 'rc' is either RC or holds command-line string responsible for the error
	
	if "`rc'"!=""  global SMrc = "`rc'"			// Put in quotes because it may be a string
	
	capture restore								// Must restore any preserved data before exit
	
	if "`msg'"!=""  {							// If there is a non-empty 'msg' add "In $errloc" if needed
		if strpos("`msg'",`"$errloc"')==0  local msg = "`msg' in $errloc" 
		local loc2 = "`loc'"					// 'loc' WILL BE USED FOR DISPLAYS, `loc2' WILL BE USED FOR STOPBOX
		if strlen("`msg'")>69  local loc = ""	// If display would wrap to next line, remove added prefix
	}											// If 'msg' already contains $errloc, change 'loc' to empty


	if $exit==1 {								// If (restored) data has been modified must also 'use' the original dataset
	   capture quietly use $origdta, clear 		// Here restore 'origdta' dataset (provided not already done so)
	   capture erase $origdta 					// (and erase the tempfile in which it was held, if any)
	} //endif	
	
												// Since we exit we must drop all globals, which yields a tricky problem addressed...
	scalar SMrc = "$SMrc"						// Save in a scalar the global copy of a non-zero error code or command
	scalar SMmsg = "`msg'"						// Save in a scalar the 'msg' argument or option
	scalar errloc = "$errloc"					// Ditto for $errloc
	scalar exit = "$exit"						// Ditto for $exit
	scalar multivarlst = "$multivarlst"			// Ditto for $multivarlst
	capture confirm existence $limitdiag
	if _rc global limitdiag = -1				// If $limitdiag not yet initialized, put it into its default state
	scalar limitdiag = $limitdiag 				// And for $limitdiag
	macro drop _all								// Clear all macros before exit (evidently including all of the above)
												// (note that scalars are not macros so they are not dropped by above command)
	global SMrc = SMrc							// Get $SMrc back from its scalar copy
	local msg = SMmsg							// Governs way in whicn msgs are displayed
	global errloc = errloc						// $errloc is needed by caller program, re-entered after wrapper 'end' command
	global exit = exit							// Ditto for $exit
	global multivarlst = multivarlst			// Ditto for $multivarlst	
	global limitdiag = limitdiag				// And for $limitdiag

	global SMreport = "reported"				// Flag, set here to survive above code, averts duplcte report from calling prog
		
	if "$SMrc"!=""  {							// If errexit was called by stackMe program with knowledge of Stata error..
	
	   capture confirm number $SMrc 			// See if it was a numeric return code
	   if _rc  {								// Not numeric so "$SMrc" holds the command line that caused the error
	   
		  if "`msg'"==""  local msg = "Stata reports likely data error in $errloc"  
		  if display !=""  display as error "`loc'`msg'{txt}" // ('display' is a scalar flag, set on entry to this program)
		  
		  if strpos("`msg'","blue")==0 window stopbox note "`loc2'`msg'; will exit on 'OK'" // Version if no "return code" in 'msg'
		  else window stopbox note "`loc2'`msg' – click on blue return code for details; will exit on 'OK'" // Else this version
		  "$SMrc"								// Invoke the command line that caused the error, so Stata reports the RC
	   }
	   
	   else  {									// Else $SMrc is numeric so likely a captured return code
	   
		  if "`msg'"==""  local msg = "Likely program error `rc' in $errloc – click blue return code for details" 
*		   							   12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		  if display !=""  noisily display as error "`loc'`msg'{txt}" // ('display' is a scalar flag, set earlier in program)
		  
		  if strpos("`msg'","click")==0 { 		// If 'msg' does not contain a 'click on blue..' clause
			 window stopbox note "`loc2'`msg'; will exit on 'OK'" 					// Version if "return code" in 'msg'			***
		  }																			  									
		  else window stopbox note ///
		  "`loc2'`msg' – click on blue return code for details; will exit on 'OK'"  // This version otherwise						***
		  
		  exit 									// NOTE THAT THIS CODEBLK PROVIDES THE msg IF THERE WAS NONE						***
		  
	   } //endelse
	   
	   scalar display = "display"				// This scalar flag might also have been set earlier in this program

	} //endif $SMrc
	
	else  {										// Else $SMrc is empty
	
	   if display !=""  {						// 'display' is a scalar; it shows 'display' was implied or optd earlier in prog
	     if strlen("`loc'`msg'")>80  {			// If total length (including any for `loc') >80...
		   dispLine "`loc'`msg'" "aserr"		// Use more that one line, if needed, to add "In $errloc"
		 }
		 else noisily display as error "`loc'`msg'"
		 window stopbox note "`loc2'`msg'; will exit on next 'OK'"
	   }
	}	

	scalar drop SMmsg filename dirpath errloc origdta exit multivarlst
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


capture program drop getprfxdvars							// Called from 'isnewvar' below

program define getprfxdvars									// Anticipate the names of outcome vars produced by current cmd
															// (check those names in case they match already extant varnames)
global errloc "getprfxdv"

local cmd = "$cmd"


* *****************
  capture noisily {											// (Syntax etc) errors in captured codeblks to up to matching close  
* *****************											//   brace will cause jump to command following that close brace

* *****************											// 2nd appearance is cluge to avoid "} is not a valid command at end
*  capture noisily {										// (Syntax etc) errors in captured codeblks to up to matching close  
* *****************											//   brace will cause jump to command following that close brace

  	
	syntax varlist, [ $mask * ] 							// Re-parse the mask for whichever 'cmd' is currently in progress
	
	local keepanything = "`varlist'"						// Should contain outcome vars (includes genyi prfxvar if multvariate)

	if substr("`duprefix'",-1,1)!="_"  local duprefix = "`duprefix'_" // same for 'duprefix'
		
	local check = ""										// Initialize the list of vars to be checked
	
	local ic = substr("$cmd",4,1)							// Put 1st significant char of `cmd' into 'ic' (initial char)
	
	if "$cmd"=="gendummies"	  local ic = "du"				// Assign 2-char initial chars for gendu and genme
	if "$cmd"=="genmeanstats" local static = "N mn sd mi ma sk ku su sw me mo" // 'static' for "stat ic"
	if "$cmd"!="gendummies" & "$cmd"!="genmeanstats"  {
	   local ic = substr("`cmd'",4,1)						// For other commands the initial char is 1st after "gen"
	}
	
	if "`cmd'"=="gendist"  	  local prfxlst = "d m p x"		// Assign 1-char initial char for other cmds
	if "`cmd'"=="geniimpute"  local prfxlst = "i m"
	if "`cmd'"=="genplace"    local prfxlst = "i m p"
	if "`cmd'"=="genyhats"    local prfxlst = "d i"
	
	
	if "`cmd'"!="gendummies" & "`cmd'"!="genmeanstats" & "`cmd'"!="genyhats"  {	// Except for these three 'non-standard' cmds
		
	   foreach prfx  of  local prfxlst  {					// Cycle thru specific prfxlist established above
															// (NOTE alternation of `prfx' with `pfx' in following code)
		  local pfx = "`ic'`prfx'"							// By default use 1-char prefix, itself prefixed by `ic'
		  if "``prfx'prefix'"!=""  local pfx = "`ic'``prfx'prefix'" // substitute user-optioned alternative, if any
		  if "`aprefix'"!=""  local pfx = "`prfx'`aprefix'"      	// Substitute `aprefix' w'out `ic' for either of above
		  else  local pfx = "`ic'`pfx'"						// Else prepend `ic' to whichever previous version prevailed
		  local pfx = "`pfx'_"								// Add suffix to whatever resulted from all the above

		  foreach var  of  local keepanything  {			// Cycle thru existing vars that outcome varnames will be based on
			 local check = "`check' `pfx'`var'"				// Subprogram 'isnewvar' (below) checks if there will be conflicts
		  } //next var										// (Only if optioned is there chance of a merge conflct, subroutine
		  
	   } //next prfx
	   
*	   ****************
	   isnewvar `check', prefix("null")						// Subprogram 'isnewvar' will add to $exists list if already exists
*	   ****************		

	} //endif 'cmd'
		
		
															// Now cycle thru the three 'non-standard' commands...
															
	if "`cmd'"=="gendummies"   {							// Commands should not create a prefixed-var that already exists
		
	   local varlist = ""									// (gendummies concern is quite different from other 'cmd's)
	   forvalues nvl = 1/NVARLSTS  {
		  local stubs = VARSTUBS`nvl'						// These may be varnames (default) or prfxvars (if found by wrapper)
		  local stublist = "`stublist' `stubs'" 
		  local prfxvar = PRFXVARS`nvl'
		  local strpfx = PRFXSTRS`nvl'
		  
		  foreach name  of  local stubs  {					// See above comment (still need to know which it was, see below)
		  
			 local stub = "du_name"							// By default a gendummies varname starts with "du_"
			 if "`stubname'"!="" local stub ="du_`stubname'" // If user optioned a stubname, use that name instead
			 if "`prfxvar'"!="" local stub = "du_`prfxvar'" // Trumped by a varlist prefixname, if any

			 if "`duprefix'"!=""{							// If user optioned a prefix to replace "du_"
			 	if substr("`duprefix'",-1,1) !="_"  local duprefix = "`duprefix'_"	
				local stub = "`duprefix'`name'"				// Make it end in "_" if user did not and use it to prefix the stub
			 }			
			 if "`noduprefix'"!=""  local stub = "`name'"	// If user optioned 'noduprefix' all of the above is moot
			 
			 local missg = ""								// Option for levelsof is empty by default
			 if "`includemissing'"!="" local missg = "miss" // But, if user optioned 'includemissing', change that optn to suit
			 quietly levelsof `stub', local(list) `missg'	// Put in 'list' the values that will suffix each new varname
			 local llen : list sizeof list					// How long is this list?
		  
			 if `llen'>15  {								// If greater than 15 new vars				
				display as error ///							   
				"Var `stub' generates `llen' new vars; see {help gendummies##categoricalVars:SPECIAL NOTE ON CATEGORICAL VARS}{txt}"
*		     	 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
				capture window stopbox rusure ///
				"Variable `stub' will generate `llen' new vars – see gendummies SPECIAL NOTE; continue anyway?"
				if _rc  {
				   errexit "Lacking permission to continue"
				   exit
				}											// Else user is ok with that number of new vars
				noisily display "Execution continues ..."

			 } //endif 'llen'								// If we emerge from this codeblk
		
			 foreach lvl  of  local list  {
				local check = "`check' `stub'`lvl'"
			 }
			 
		  } //next 'name'
		  
	   } //next 'nvl'
	   
	   
*	   ****************
	   isnewvar `check', prefix("null")						// Subprogram 'isnewvar' will add to $exists list if already exists
*	   ****************										// (permission to drop vars in that list will be sought following


/*										
											// CODE HERE COMMENTED OUT MAY BE HELPFUL IF LATER VERSION IMPLEMENTS 'RECORDMISSING' 
											// OPTION FOR 'gendummies'
									
	   if ("`newvar'"!="`var'") {							// Exclude the stub itself
				
		  qui replace `newvar' = 0 if `var'>=.
					   
		  if "`recordmissing'"!=""	{						// See if user requested additional var for each missing value
		  
			 local nmv = 0									// Initialize count of different missing values
					  
			 preserve  
					  
				drop if `var'<.								// Drop all non-missing observations
				sort `var' 									// Sort `var' in order of its missing values
				while _N>0  {								// While there are any remaining observations
					local nmv = `nmv'+1							// Increment `nm'
					local val`nmv' = min(`var')				// Put value of lowest missing value in val`nm'
					drop if `var'< val`nmv'					// Drop observations with missing values less than this
				} //nextwhile
						 
			 restore										// Restore working data
					  
			 forvalues i = 1/`nmv'  {						// Cycle thru all seperate missing values found, up to max `nm'
				gen `newvar'mis`i' = val`nmv'				// Generate a new var for each missval filled with that value
				qui replace `newvar'mis`i' = `newvar' if `newvar'<.
			 } //next 'i'
					  
		  } //endif 'recordmissing'							// Replace that value with original value for non-missing obs
		  
	   } //endif `var'
*/
		
	} //endif 'cmd'=='gendummies'

	
/*															// COMMENTED OUT PENDING TESTS USING 'STANDARD COMMAND' CODE, ABOVE

	if "`cmd'"=="geniimpute"  {								// Commands should not create a prefixed-var that already exists
	   foreach prfx  in  i m  {								// Default prfx names just one char, used (eg) in option 'dprefix'
		  local pfx = "i`prfx'`aprefix'"					// Construct default prefix (w extra "d" for "dist" & 'aprefix' if any)
		  if "``prfx'prefix'"!=""  {						// If user optioned a different prefix than this particular prfx ...
			 local pfx = "i``prfx'prefix'"					// (then append that char to referenced string – hence double ``'')
		  } //endif											// (all ?prefix options were standardized earlier to end in "_")
		  else if "`aprefix'"=="" local pfx = "i`prfx'_" 	// If both optionable prefixes are empty use default, followed by "_"
															// (this overrides any aprefix, for the particular prefix concerned)
		  foreach var  of  local keepanything  {				// List of existing vars that outcome varnames will be based on
			 local check = "`check' `pfx'`var'"
		  } //next var										// (Only if optioned is there chance of a merge conflct, subroutine
	   } //next prfx										// 'isnewvar' checks whether the prefixed var exists in 'origdta')
*	   ****************
	   isnewvar `check', prefix("null")						// Subprogram 'isnewvar' will add to $exists list if already exists
*	   ****************
	} //endif 'cmd'	== 'geniimpute'							// (permission to drop vars in that list will be sought following															// 'null' option signals no separate list of default-prefixed vars
															//  genyhats codeblock, below)
*/	
	
	if "`cmd'"=="genmeanstats"  local prfxlst = "`static"	// Cmd genme, where other 'cmds' have an optlist, has a list of 'ic's

	if "`cmd'"=="genmeanstats"  {							// Commands should not create a prefixed-var that already exists
	   foreach prfx  in  N mn sd mi ma sk ku su sw me mo  {
		  local ic = "`prfx'`aprefix'_"						// Construct default ic (w extra 'aprefix' if any)
		   
		  foreach var  of  local keepanything  {			// List of existing vars that outcome varnames will be based on
			 local check = "`check' `ic'`var'"
		  } //next var										// (Only if optioned is there chance of a merge conflct, subroutine
	   } //next prfx										//  'isnewvar' checks whether the prefixed var exists in 'origdta')
*	   ****************									    // (program isnewvar, below, asks for permission to replace if so)
	   isnewvar `check', prefix("null")						// Subprogram 'isnewvar' will add to $exists list if already exists
*	   ****************										// (permission to drop vars in that list will be sought following
	} //endif `cmd'=='genmeanstats'							//  'genyhats' codeblock, below)
															
	
	
/*															// COMMENTED OUT PENDING TESTS USING 'STANDARD COMMAND' CODE, ABOVE

	if "`cmd'"=="genplace"  {								// Commands should not create a prefixed-var that already exists	
	   foreach prfx  in  i m p  {							// Default prfx names just one char, used (eg) in option 'dprefix'
		  local pfx = "p`prfx'`aprefix'"					// Construct default prefix (w extra "p" for "place" & 'aprefix' if any)
		  if "``prfx'prefix'"!=""  {						// If user optioned a different prefix ...
		     local pfx = "p``prfx'prefix'"					// (then append that char to referenced string – hence double ``'')
		  } //endif
		  else if "`aprefix'"=="" local pfx = "p`prfx'_'" 	// If both optionable prefixes are empty use default, followed by "_"
															// (this overrides any aprefix, for the particular prefix concerned)
		  foreach var  of  local keepanything  {			// List of existing vars that outcome varnames will be based on
			 local check = "`check' `pfx'`var'"
		  } //next var										// (Only if optioned is there chance of a merge conflct, subroutine
	   } //next prfx										// 'isnewvar' checks whether the prefixed var exists in 'origdta')
*	   ****************									    // (program isnewvar, below, asks for permission to replace if so)
	   isnewvar `check', prefix("null")						// Subprogram 'isnewvar' will add to $exists list if already exists
*	   ****************										// (permission to drop vars in that list will be sought following
	} //endif 'cmd'=='genplace								// (permission to drop vars in that list will be sought following
															//  'genyhats' codeblock, below)
															// ('null' option signals no additional prefix (eg for gendummies)		
*/														
															
	if "`cmd'"=="genyhats"  {								// (genyhats, like gendummies, is a variant on the general pattern)
	   
	   foreach var  of  local keepanything  {				// List of existing vars that outcome varnames will be based on
															// ('prfxvar', below, from codeblk (2.1) holds a prefix var(list)
		  if "`prfxvar'"=="" & "`multivariate'"==""  {		// If this is NOT a multivariate procedure (empty prfxvar & no flag)
			 local pfx = "yi`aprefix'"						// Outcome vars will be prefixed with 'yi_' & may include 'aprefix'
			 if "`iprefix'"!="" {
			 	local pfx = "y`iprefix'`aprefix'"  			// If 'iprefix' was optd, use that prefix (with any aprefix)
			 }
			 local check = "`check' `pfx'`var'"				// Add it to list of vars to be checked
		  }	//endif
		  
		  else  {											// Else this multivariate varlist is prefixed with depvarname
			 local pfx = "yd`aprefix'"						// (unless user options a different d-prefix for multivariate)
			 if "`dprefix'"!="" {
				local pfx = "y`dprefix'`aprefix'"			// If 'dprefix' was optd, use that prefix (with any aprefix)
			 }
			 if "`prfxvar'"!=""  local depvar = "`prfxvar'"	// If there was a prefixvar that becomes the depvar (otherwise optd)
			 local check = "`check' `pfx'`depvar'"			// Add it to list of vars to be checked													
		  } //endelse										// (OPTIONED DEPVAR IS MANDATORY if there is no `prfxvar')				***

		  
	   } //next var											// (program isnewvar, below, asks for permission to replace)
	   
*	   ****************	   
	   isnewvar `check', prefix("null")						// Check to see if relevant prefixed vars already exist
*	   ****************	   
	} //endif `cmd'=='genyhats'								// (and drop the prefixed vars if user responds with 'ok')
			
	
	
	
	
	if "$badvars"!=""  {									// If there are vars w upper case prefix, maybe from prior error exit
	   local badvars = ""									// (this global was filled by subprogram 'isnewvar')
	   foreach var  of  global badvars  {
	   	  local badvars = "`badvars' " + lower(substr("$badvars",1,1)) + substr("$badvars",2,.)
	   }													// Make first char of such variable names lower case
	   
	   dispLine "Some vars seemingly left from earlier error exit: `badvars'; drop these?" "aserr"
															// (produced by subprogram 'isnewvar', bi-product o code above)
	   if strlen("$badvars")>277  global badvars = substr("$badvars",1,260)+"..." // Stopbox only holds 320 chars
	   capture window stopbox rusure "Drop variables seemingly left from earlier error exit?: $badvars"
*						              12345678901234567890123456789012345678901234567890123456789012345678901234567890 
	   if _rc  {											// Non-zero return code tells us dropping is not ok with user
		   errexit, msg("Lacking permission to drop unused vars") 
	   }													// (might have changed working dta by dropping $exists)
	    
	   else  {												// Else drop these existing vars
	   	 drop $badvars
*		 global badvars = ""								// This global retained to drop vars already saved in 'origdta'			***
	   }													// (NOT SURE WHY when that is restored in codeblk (10) below)
	   
	} //endif $badvars
	
	
	
	
	
	if "$newprfxdvars"!=""  {								// This global was filled by subprogram 'isnewvar'  
															// (called from code in wrapper(5)
		local newprfxdvars = "$newprfxdvars"				// Could avoid this line if '(global) newprfxdvars' is allowed
		local dups : list dups newprfxdvars					// ***********************************************************
		if "`dups'"!=""  {									// THIS CODEBLOCK ADDRESSES TWO PROBLEMS: (1) deal with dups
		   local ndups = wordcount("`dups'")				// (2) PREVENT MERGE FINDING APPARENT CONFLICT DESPITE FACT THAT
		   local duplen = strlen("`dups'")					//     RENAMING AFTER MERGE WILL AVERT THAT CONFLICT
		   if `ndups'==1  { 								// **************************************************
		   	  errexit "Duplicate outcome varname `dups'"
			  exit
		   }
		   else  {											// If N of dups>1
			  if (`duplen'+ 28)<81  display as error "Duplicate outcome varnames: `dups'"
			  else {										// Else too long for one-line display
			  	local txt = "Duplicate outcome varnames: `dups'"
			  	dispLine "`txt'" "aserr"					// Format long list of vars line-by-line and display as error
			  }
		   }
		   if `duplen'>248  local txt = substr("Duplicate outcome varnames: `dups'",1,245) + "..."
		   else local txt = "Duplicate outcome varnames: `dups'" 
		   errexit, msg("`txt'")							// 'opts' format errexit does not display on console, only in stopbox
		   exit

		} //endif 'dups'
		
		global namechange = ""
		foreach var  of  global newprfxdvars  {				// HERE WE DEAL WITH APPARENT MERGE CONFLICTS ARISING FROM NAME CHANGES
															// THAT WON'T TAKE EFFECT UNTIL THE cleanUp STAGE THAT FOLLOWS MERGE
		   capture confirm variable `var'
		   if _rc ==0  {									// If return code indicates this is an existing variable
		   
		   	  local tempname = strupper(substr("`var'",1,1)) + substr("`var'",2,.)
			  rename `var' `tempname'						// Make strupper first char of existing potentially conflicted name
			  global namechange = "$namechange `tempname'"	// (name change will be reversed in cleanUp <- wrapper, after prefixing)
		   }
															// GLOBAL 'namechange' WILL GOVERN REPLACEMENT OF ORIGINAL NAMES IN 
		}													// SUBPROGRAM cleanUp, CALLED FROM WRAPPER CODEBLK (10)
		
	} //endif $newprfxdvars
	
	local skipcapture = "skip"								// Flag to skip the endcapture block if entered it from here
	
	
* **************	
  if "$cmd"=="gendummies"  exit								// Avoids  "} is not a valid command name"  error
  } //endcapture											
* **************
 
  if _rc & "`skipcapture'"==""  {
   	 errexit "Error in getprfxd"
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
   	  errexit "Error in getwtvars"
      exit
    }
														
	

end getwtvars



********************************************************************************************************************************



capture program drop isnewvar								// Called from wrapper(5) (NO LONGER CALLED FROM gendist in VERSION 2)

program isnewvar											// New vars DO NOT ALL have prefixes, SO $prfxdvars IS MIS-NAMED

version 9.0

  global errloc "isnewvar"
	
	
* *****************
  capture noisily {
* *****************

	syntax anything, prefix(string)
	
	if "`prefix'"=="null"  local prefix = ""				// No prefix will be prepended to anything-var if prefix is "null"
	else local prefix = "`prefix'_"							// Else add underline to end of 'prefix'
	if strpos("`prefix'","_")==3  {							// If this was a two-character prefix
		
	}
	
	local ncheck : list sizeof anything						// 'anything' may have several varnames
	
	forvalues i = 1/`ncheck'  {								// anything already has default prefix for each var
	
	  local var = word("`anything'",`i')
	  if "`prefix'"!=""  local var = "`prefix'_`var'"		// If a(n additional) prefix was optioned (eg for genyhats)..
	  capture confirm variable `var'						// These vars have their final prefixes (default or optioned)
	  if _rc==0  {											// If that variable already exists ...
	    global prfxdvars = "$prfxdvars `var'"				// Add to global list final names of outcome vars
		global exists = "$exists `var'"						// Add to global list initial names of corresponding inputs
	  }														// (but ALL new vars are included, may not have prefix – eg gendummies)
	  else global newprfxdvars = "$newprfxdvars `var'"		// List of prefixed outcome that don't yet exist
	  
*	  mata:st_numscalar("a", ascii(substr("`var'",1,1))) 	// Get MATA to tell us the ascii value of the initial char in `var'
*	  if a>64 & a<91  continue								// Skip any vars having prefixes whose 1st char is upper case
															// (COMMENTED OUT and now put into list of $badvars, below)
	  local prfx = strupper(substr("`var'",1,1))			// Extract minimal prefix from head of 'var' & change to upper case
	  local badvar = "`prfx'"+substr("`var'",2,.)			// Potential badvar's prefix now has upper case 1st char
	  capture confirm variable `badvar'						// Confirm that such a var is left over from previous error exit
	  if _rc==0  {
	  	global badvars = "$badvars `badvar'"				// If so, add to list of such vars
	  }
	  
	} //next i (becomes var)
	
	local skipcapture = "skip"

* **************
  } //endcapture
* **************
  
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in isnewvar"
      exit
   }
														
  
	
end //isnewvar



********************************************************************************************************************************


capture program drop showdiag1

program define showdiag1

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
   	  errexit "Error in showdiag1"
      exit
   }
														
	

end showdiag1



********************************************************************************************************************************


capture program drop showdiag2

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
																	  // 'geniimpute' prints its own diagnostics																	  // (`lbl' is a local copy of scalar LBL used within a single program)
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
   	  errexit "Error in showdiag2"
      exit
   }
														
	
			
end showdiag2



********************************************************************************************************************************


capture program drop stubsImpliedByVars

program define stubsImpliedByVars, rclass		// Subprogram produces a list of stubs corresponding to multiple varlists
												// (check those names in case they match already extant varnames)

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
	   checkvars "`prepipes'"									// 'checkvars' will collect invalid vars in 'errlst'
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
   	  errexit "Error in stubsimplied"
      exit
   }
														

																	
end stubsImpliedByVars



********************************************************************************************************************************

	
capture program drop subinoptarg

program define subinoptarg, rclass					// Program to remove supposed vars from varlist if they prove to be strings
													// or for other reasons (MAY NOT BE CALLED)
global errloc "subinopta"


* ***************
  capture noisily {
* ***************


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
			exit
		}
	}
	return local options `options'
	
	local skipcapture = "skip"

	
*	************
  } //endcapture
*	************
  
   if _rc & "`skipcapture'"==""  {
   	  errexit "Error in subinopt"
      exit
   }
												


end subinoptarg



********************************************************************************************************************************


capture program drop varsImpliedByStubs

program define varsImpliedByStubs, rclass		// Subprogram converts list of variable stubnames to a list of vars implied 
												// (eliminating false positives with longer stubs)
global errloc "varsImpl"


* ****************
  capture noisily {
* ****************

	syntax namelist(name=keep)
	
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

