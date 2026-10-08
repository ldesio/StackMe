*! ****************************************************
*! 'stackmeWrapper' versn 10a, Stata version 16.1, Aug'26, buildng on Apr-Aug '23, Apr '24-May'25 by Mark from major re-write in June'22
*! ****************************************************

*! THIS WRAPPER HAS BEEN USED AS A TEST-BED FOR TEN VERSIONS OF WHAT WE STILL CALL 'stackMe' v2 – A TEST-BED WHOSE LEGACY CODE STILL 
*! LITTERS THE CURRENT VERSION, AS OF OCTOBER 2026, RESULTING IN FAR MORE CODE THAN NEEDED FOR THIS VERSION BUT SIMPLIFYING ANY POSSIBLE
*! FUTURE REVERSION TO EARLIER CODE – OR INTRODUCTION OF ALTERNATIVE USER INTERFACE ELEMENTS.

*! Version 10a simplifies the remaining compexities in Version 10 syntax by allowing multiple varlists to each have option-lists that
*! can include any or all options listed in that command's helpfile. The only remaining restrictions relate to [if] and [in] varlist
*! suffixes. These can only occur on the first varlist of any set of varlists, ensuring that all varlist-optlists appended to any
*! command employs the same exact set of data. [wt] expressions can still be supplied following any/all varlist(s) in the set.

*! It is galling to think that, had I imagined this straightforward fix for the problem of invoking multiple varlists with one command
*! I could probably have saved several years of program design and debugging. Basically I just assumed there would be many options that 
*! could not be invoked more than once for any command, and failed to test that assumption until experience showed it to be wanting.

*! Version 10 tried to modify the user syntax used to invoke a 'gen..' command, allowing the user to specify an option-list for each
*! of however many varlists might be specified. That version allowed a first varoptlist to be followd by additnal varwtoptlsts but, ON
*! SUBSEQUENT OPTION-LISTS, ONLY 'opt1', 'aprefix' AND 'multivariate' OPTIONS, ALONG WITH THE VARLIST'S weight EXPRESSION COULD BE 
*! ALTERED). But the extent of this restrictiveness proved unnecessary. Hence the v10a revision.

*! HOWEVER, it then occurred to me that there was a different way of saving the overhead of parsing a long 'syntax' command for each
*! country-context. This is to reconstruct the original syntax mask (provided in each stackMe command's caller program) to contain only
*! optname – or optname(descriptor) – mask elements that are actually user-optioned on each individual command-line. Conceptually this
*! seemed straightforward but in practice it has taken several weeks to work out the necessary details and associated bugs. Time well-
*! spent, I hope, but well-spent time can add up to years if there are enough instances of such "improvements" !!


capture program drop stackmeWrapper

*!  This ado file is called from each stackMe command-specific caller program and contains program 'stackmeWrapper' that forwards calls
*!  onward to `cmd'O and `cmd'P subprograms, where `cmd' names a stackMe command. This wrapper program also calls on various subprograms
*!  meant primarily to reduce the complexity of wrapper codeblocks. Those include 'varsImpliedByStubs' 'checkvars' and 'errexit', among
*!  others, whose code is appended following the code for 'stackmeWrapper'. Additional subprograms – so-called "utility programs" – can 
*!  be found in an ado file named 'stackMe.ado'. Several of these ('SMsetcontexts' 'SMfilename' and 'SMitemvars') can be directly invoked
*!  by users, but such usage should be rare except for the required user-invocation of the 'SMsetcontexts' utility program, which should  
*!  be the first stackMe command invoked by a user intending to employ any dataset with stackMe for the first time. See the helpfile for
*!  'help stackMe' that should be required browsing for anyone hoping to make sense of the codeblocks that follow below.

*!  'stackmeWrapper' versions 4-9; Stata version 9.0; updatd Apr, Aug '23 & again Apr '24 to May'25 by Mark from major re-write in June'22
*!  Version 4 replicated normal Stata syntax on every varlist of a v.2 command (eliminates previous cumulation of optns across varlsts)
*!  Version 5 simplified version 4 by limiting positioning of ifin expressions to first varlist and options to last varlist,
*!  Version 6 implemented 'SMsetcontexts' and the experimental movement of all preliminary 'genplace' code to 'genplaceO'.
*!  Version 7 revives and improves code from Version 3 that tried to identify the actual variable(s) employed in a weight expression.
*!  Version 8 moves additional "opening" codeblocks to new `cmd'O programs, for 'gendist', 'geniimpute', and 'genstacks'; and, in v9,
*!  Version 9 introduces $varlist, $prfxvar, $prfxstr globals so `cmd'P programs need not do so. These later evolved into scalars and,
*!			  ultimately, into data characteristics that avoid having those globals emptied or overwritten by preserve/restore/merge 
*!			  operations. Also experimented with simpler 'append' code that accumulated contexts and appended current context to that  
*!			  file – seemingly slowing execution and thereby confirming the use of the more elaborate coding.

*!  AT SOME POINT INVESTIGATE USE OF STATA 'snapshot' COMMAND IN LIEU OF 'preserve' SO 'stackMe' WILL WORK ON PRESERVED DATA. This idea
*!  had evolved by Version 10, into the idea of using dataframes, but that evolution has still not happened, as of Aug'26						***

										// For a detailed introduction to the data-preparation objectives of the stackMe package, 
										// see 'help stackme'.
										
*****************************
program define stackmeWrapper	  		// A "wrapper" called by `cmd'.ado (the ado file named for any user-invoked stackMe command)
***************************** 

scalar SAVE0 = "`0'"					// Save 2 existing macros of relevance to this invocation of 'stackmeWrapper' (see below).
scalar PAUSEON = "$PAUSEON"
										// This wrapper calls `cmd'O, once each, for several commands and then repeatedly calls `cmd'P
										// (the program doing the heavy lifting for that command) where context-specific processing
										// generally takes place, one context per call on `cmd'P. The wrapper also parses the user- 
										// supplied stackMe command line, reduces the active data to user-named/implied variables and 
										// sets up options and varlist(s) for calls on `cmd'O and `cmd'P. It then manages the accumula-
										// tion of files, one for each context, and merges those files with the original datafile before
										// calling on subprogram 'cleanup' to post-process the outcome data, as per user-specified
										// options, before returning execution to the original calling program, which exits Stata. 
										
										// This complex structure fulfills the design goals to (1) access each data observation the 
										// minimum possible number of times per stackMe operation and (2) have the same code provide any 
										// service required by all stackMe commands, simplifying program maintnence and error-correction.
*		********						
* 		Summary:						// Wrapper for stackMe version 2.0, June 2022, updated in '23, '24 '25, '26. Version 8 & later 
*		********						// extract working data (vars and observations determined by each stackMe command-line) before  
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
										// should be reported to the authors, along with copies of the data & ado files responsible.
*		*******							
* 		Syntax:	
*		*******							// General syntax: << cmd varlst [ifin] [wt] [, optns || varlst [wt], optns ||... >>
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
										// takes a suprising amount of code). From each input varoptlist, extract the names from which 
										// outcome variable names will be constructed. On the basis of these two lists, form a combined
										// list uniquely identifying the variables to be retained in working dta. Ensure that the names
										// of variables to be created do not duplicate any existing variable names.
										//
										// 2. Save the original datafile for later merging with genereted variables; drop variables 
										// and oservations not needed in the working data; conduct preliminary checks for anticipated 
										// likely errors in the current 'cmd'P; often invoke a preliminary 'cmd'O (for 'open') sub-
										// program that performs preliminary processing that requires access to all observations in 
										// the full dataset. then repeatedly invoke `cmd'P (for program), once for each context.
										//
										// 3. For each context (e.g. country-year-stack), preserve the working dataset and drop from 
										// the active data all contexts other than the currently active context (generlly stack-within
										// context but context-level for 'genstacks' and 'genplace'); invoke 'cmd'P (for program) that
										// does the heavy lifting, transforming input vars into appropriately-processed outcome vars.
										//
										// 4. Store processed data for each context in a separate tempfile. When all contexts have been
										// processed append each of those separate files to the first of them (the file on which the
										// full dataset is built), deleting each of the tempfiles after appending. Finally merge the 
										// complete file of working data back into the original dataset (all new vars have new names,
										// generally constructed by prepending a prefix or adding a suffix to the original name).
										//
										// 5. Save working subset in a single tempfile that, after the first context (whose outcome
										// data is saved as foundation), is appended to the growing tempfile of outcome data; restore 
										// the original dataset mentioned in 2, above, and merge it with the tempfile of outcome data
										// from 3, above; report (if optioned) on missing observations per context and overall.
										// 
										// 6. Call the 'cleanup' subprogram where variables are renamed and otherwise post-processed 
										// or dropped, as optioned. 
										//
										// The wrapper program attempts to capture all user errors and provide maximally helpful
										// error messages, processed by subprogram 'errexit' which itself calls 'dispLine' to format
										// and display any messages containing more than 80 characters. It also captures all program
										// errors and tries to make sense of those but, at minimum, restores the original data before
										// exiting.
										//
										//			  Lines suspected of still proving problematic are flagged in right margin      	***
										//			  Lines needing customizing to specific `cmd's are flagged in right margin    	 	 **

										
*		************************		// Commands framed by asterisks play a critical role in defining stackMe package structure
*		commands to look out for		// (see examples to left). Comments framed in the same manner explicate features of stackMe
*		************************		// package structure.
									
									
*		************************		// WE MAKE FREQUENT REFERENCE TO A "FLAG" OPTION, WHAT THE STATA MANUAL CALLS AN "ON" OPTION.
		macro drop _all					// Global flags, etc., may have remained active on earlier error exit, so this cmd is issued
		global save0 = SAVE0			// here – the earliest point where all stackMe commands share the same lines of program code.
		global PAUSEON = PAUSEON		// We don't want PAUSEON turned off at start of every stacmMe command ('SAVE0' & 'PAUSEON' are 
		scalar drop _all				// scalars set at top of left-hand column; similar scalar useage is seen in programs 'errexit'
*		************************		// and and 'stackmeWrapper', and in the final codeblock of each caller program).

		capture drop ___*				// Drop quasi-temporary variables, used to avert naming conflicts, remaining after error exit.
										
*		**************************		// Used by subprogram 'errexit' where un-anticipated Stata-reported non-zero return codes are 
		global errloc "wrapper(0)"		// sent when captured. Global errloc stores a string that roughly identifies likely locations
*		**************************		// for error occurrance. User errors are handled more specifically in the codeblocks where such 
										// errors are identified; but even these (ultimately) yield a call on subprogram 'errexit' 
										// (appended), which restores the original data (if changed by the time the error is identified).
										
*		******************
*		Coding conventions				// Sevral commonly-used coding conventions are faund in stackMe programs to ease code comprehen-  
*		******************				// sion; a less common convention is to put command names and command strings within standard  
										// single quotes (''), to distinguish them from names of locals, placed within Stata-defined 
										// single quotes (`') where this helps comprehension; but this convention is unfortunately not   
										// ubiquitous (it was adopted late in the coding process).
										
*****************
capture noisily {						// Here is the opening brace of a capture that encloses remaining wrapper code, except for a
*****************						// final codeblock that processes any captured errors. (That codeblk follows the close brace 
										// that ends the span of code within which errors are captured).

										// *******************************************************************************************
*capture noisily {						// This command is a cluge to prevent the matching close-brace (blk 11) from flagging an error
										// (commented out since not currently needed but retained as text in case of future need)
										// *******************************************************************************************
										
										// *******************************************************************************************
										// STACKME USES DATA CHARACTERISTCS TO STORE WHAT WOULD HAVE BEEN GLOBALS, HAD THOSE PERSISTED
										// ACROSS 'preserve'/'restore' COMMANDS. ALSO ENSURES NO GLOBALS ARE LEFT HANGING AROUND AFTER
										// ERROR EXIT. HERE WE CLEAR ANY SUCH CHARACTRSTCS LEFT HANGING AFTER PREVIOUS STACKME COMMAND
										// *******************************************************************************************
		
  local versn = "10"					// Permits conditional codelines executed only for v10 (or vice versa)
										// (previous versiond did not have hardwired version numbers)
  local nvarlsts : char _dta[NVARLISTS] // Retrieve count for number of varlists on command-line of most recent 'stackMe' command
	
  if "`nvarlsts'"!=""  {				// If there was such a characteristic established for this dataset ..
	
	 forvalues nvl = 1/`nvarlsts'  {	// Then clear all the multivarlist _dta characteristics for that dataset
		
	    local nvl = `nvl' + 1
	    foreach charname in VARLISTS OPTIONS PRFXVARS PRFXSTRS VARSTUBS MULTIVARIATE NOOBSVARLST MASK  {
	      char _dta[`charname'`nvl']	// Clear each characteristic having numeric suffix for each varlist
	    }
	 }
  }
	
	char _dta[NVARLISTS]				// Clear # of varlists on command-line; clear following chars used in lieu of globals																				
	char _dta[MULTIVARLST]				// Clear the list of varlistIfinwtOpts separated by ||
	char _dta[VARLISTNO]				// Clear the list of varlist# where each outcomename originated
	char _dta[NAMECHANGE]				// Clear char stored in 'getprfxdvars', governing tempvar renamng in blk(4)
	char _dta[STATRTRN]					// Clear charactrstc specific to cmd 'genmeanstats'
	char _dta[STATPRFX]					// Clear ditto (lines up with pre-wrappr(3) charactrstcs `cos both were created sequantially)
	char _dta[LIMITDIAG]				// Clear user-optioned number of contexts for which to report diagnostics
	char _dta[OUTCMNAMES]				// Clear outcomenames char (as many`outcmnames' as there are different outcome prfxs)
	char _dta[INPUTNAMES]				// Clear `inputnames' (as many as there are different outcome prfxs)
	char _dta[STUBNAMES]				// Clear n of stubnames provided for the `gendummies' command
	char _dta[PRFXNAMES]				// Ditto  for prfxnames (CALLING THEM prfxvars IS UNFORTUNATE LEGACY NAMING CHOICE)				***
	char _dta[STATRTRN]					// Ditto for genmeanstat optioned statistics
	char _dta[STATPRFX]					// Ditto for genme outcome prefixes
	char _dta[OPTNAMES]					// Clear charactrstc Used to communicate between subprograms 'getprfxnm' and 'getoutcmnames'
	char _dta[SPFXLST]					// Clear string-prefix list
										// (don't confuse with `strprfx'; derived from char set before wrapper(3))
	char _dta[INTERIMS]					// Clear char used by gendummiesP to communicate its interim names to subprogram 'cleanup'
	char _dta[CONTEXTVARS]				// Clear contextvars charactrstic (matching lower case local is SMsetcontext version)
	char _dta[CUMULATE]					// Clear workflow history, (more detailed than the version held in outcome var labels)
  
										
										
										
global errloc "wrapper(0.1)"			//		********************************************************************************
pause(0)								// (0)  Preliminary codeblock establishes name of latest data file used or saved by any 
										// 		Stata command and other globals needed throughout stackmeWrapper. Initialization 
										//		of a further large number of locals is documented at start of codeblk (2)
										//		********************************************************************************
										
	global keepvars = ""									// Local holding varnames includng optiond vars with dups & sepratrs removed
	global noweight = "noweight"							// Default setting assumes no weight expression appended to any varlist
	global SMreport = ""									// Signals error msg already reportd, to 'errexit' and to calling programs.
	global exit = 0											// Signals to wrapper the current state of data usage:
															//  $exit==1 requires restoration of SMorigdta; $exit==0 or $exit==2 doesn't
															//  ('exit 1' is a commnd – sets return code=1 –  $exit=1 is flag for caller)
															
	global nvarlst = 0										// N of varlists on commnd line is initialized to 0

	local filename : char _dta[filename]					// Get established filename if already set as dta characteristic

	if "`filename'"==""  {
	
		display as error //
		"This datafile should be initialized by {help SMutilities##SMsetcontexts:{ul:SMset}textvars} for use by {bf:stackMe}"

		window stopbox stop "This datafile has not been initialized by 'SMsetcontexts' for use by 'stackMe' – see displayed message"

	} //endif filename										// Need user to read help text before starting!
	
	
	
	capture confirm variable SMstkid						// See if dataset is already stacked
															// **********************************************************************
															// Remaining lines of wrapper(0) (current codeblk) ensure conformity of 
															// "special variables" SMstkid & S2stkid with filename prefix
															// ***********************************************************************
	if _rc==0  {											// If there IS a variable named SMstkid, suggesting data are stacked, ...
	   gettoken prefix rest: filename, parse("_") 			// Then check for correct prefix to filename
	   if "`prefix'"!="STKD" & "`prefix'"!="S2KD"  {
		  window stopbox note "Dataset with SMstkid variable should have filename with STKD_ (or S2KD_) prefix"
*                  			   12345678901234567890123456789012345678901234567890123456789012345678901234567890
		  local warnexit = "warn"							// Need to warn of implications before exit (alternative path)
	   }
	   capture confirm variable S2stkid						// See if dataset is already double-stacked
	   if _rc==0  {											// If there IS var named S2stkid, suggesting data are double-stacked
	     if "`prefix'"!="S2KD"  {
		    window stopbox note "Dataset with S2stkid variable should have filename with S2KD prefix"
*                  				12345678901234567890123456789012345678901234567890123456789012345678901234567890
		    local warnexit = "warn"							// Need to warn of implications before exit (alternative path)
	     }
	   } // endif _rc
	} //endif _rc		
	  
	else  {													// Else there is no SMstkid variable in the dataset
	   if "`cmd'"=="genstacks"  {							// If 'genstacks' is caller that brought us here
		  gettoken prefix rest: filename, parse("_") 		//  check for correct prefix to filename (genst cannot access locals
															//  initialized here)
		  if "`prefix'"=="STKD" | "`prefix'"=="S2KD"  {
		    window stopbox note "Dataset without SMskid var should not have filename with STKD_ or S2KD_ prefix"
*                  				 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		    local warnexit = "warn"							// Need to warn of implications before exit (alternative path)
		  }	  
	   } //endif `cmd'=="genstacks"
	} //endelse _rc
	
	if "`warnexit'"!=""  {									// This warning applies to both of two possible error msgs, above
		display as error "Bad file configuration; see help {help stackMe} for suggested stackMe workflow"
*                  		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		errexit, msg("See stackMe helpfile for suggested stackMe workflow") // (oprioned `msg' is not displayed on console)
		exit 1												// Exit to calling program after exit from 'errexit'
	}
	
	local needopts = 1										// MOST COMMANDS NEED OPTIONS-LIST (exceptns are ON 3rd line of codeblk 0.1)
	
	

	
	
	
	
global errloc "wrapper(0.1)"
pause(0.1)	


										//		 *************************************************************************************
										// (0.1) Codeblock to pre-process the command-line passed from `cmd', the calling program. 
										//       It divides up that line into its 2 basic components: `cmd' (the stackMe commend name)  
										//       and `cmdstr' – as many combined <varlist/namelist with ifinwt expressns and opt-lists>
										//       as may occur before the syntax mask that follows a "\", terminator for what the user
										//		 typed. The code extracts the `multiCntxt' flag and `prefixtype' argument that preceed 
										//		 the parsing `mask' (see any calling `cmd' for details); it discovers the option-name 
										//		 of the first argument – an option that will hold any varname or list of varnames 
										//		 that might provide additional inputs to a stackMe command.
										//		 **************************************************************************************
										
										//		 ***************************************************************************************
										//		 NOTE THAT v10 CODE THROUGHOUT ALL PROGRAMS STILL ASSUMES THAT `opt1' CAN BE SUPPLIED BY
										//		 "PREFIX VARIABLES" AND THAT CERTAIN PREFIXES TO VARNAMES CAN BE SUPPLIED BY THE STRING
										//		 PREFIX TO SUCH VARIABLES. THIS AFFECTS ESPECIALLY THE NAMES OF SOME GLOBALS & SCALARS.
										//		 THESE `prfxvars' AND `prfxstrs', IN v9 AND PRIOR MADE CRITICAL `options' REDUNDANT.
										//		 ***************************************************************************************
	
	
	gettoken cmd rest : (global) save0						// Get the commandname from head of global save0 (what the user typed) –
															// saved in global save0 after 'Commands to look out for', above.
															// `gettoken' primes local `rest' for the next 'gettoken', below and provides
	global cmd = "`cmd'"									//  a global accessible from other programs)
															// Now see if `cmd' is any of the three listed commandnames
	if strpos("gendummies genmeanstats genstacks","`cmd'")  local needopts = 0 		// ADD OTHER EXCEPTIONS, AS FOUND 					***
															// These three stackMe commands do not require an options-list
															
	
	gettoken cmdstr mask : rest, parse("\")					// Split rest' into the command string and the syntax mask (`cmdstr' is
															// what the user typed), following `cmd'name & up to & including "\".
							  
	local mask = substr(strtrim("`mask'"),2,.) 				// Remove "\" that heads the mask, after trimming off any leading blanks 
	if substr(strtrim("`cmdstr'"),-2,2)=="||"  {			// If the final two non-blank chars of `cmdstr' are "||"
	   errexit "Pipes ("||") not allowed after final varWtOptlist" // (note that first `varwtoptlist' may include an 'ifin' expression)
	   exit 1												// errexit error string cannot exceed 80 chars
	}														// `errexit' IS USER-WRITTEN ERROR-HANDLING SUBPROGRAM AT END OF THIS DOFILE
															
	gettoken istwrd mask : mask								// See if 1st word ('head') of remaining `mask' is a "multicntxt" flag
	if "`istwrd'"=="multicntxt"  {							// (else it will be the option inserted by caller prog, processed below)
	   local multiCntxt = "multiCntxt"						// Reset multiCntxt local (initially empty) if "multiCntxt" string !=""
	}														// (in either case that word has now beem removed from head of `mask')
	
	else  {													// Else first word is not "multiCntxt" so it must be next word inserted
															//  by caller before start or mask – that word (an option) is always present
		local multiCntxt = ""								//  THIS CLUGE GETS US TWO EXTRA FLAGS THAT WERE NOT IN ORIGINAL DESIGN
		local mask = "`istwrd' `mask'"						// Re-assemble mask by prepending whatever was in `istwrd' to rest ('tail')
	}														//  of mask, but now with both "multicntxt" flag and leading "\" removed

	gettoken prfxtyp mask : mask							// Either way, next word is `prxtyp' (one of "var" or "othr" or "none")
															// (placed there by caller wrapper's program and followed by rest of mask) 
															// (and removed by above 'gettoken' so next word in `mask' is `opt1')
	gettoken preparen postparen : mask, parse("(")			// Identify the option-name for critical 1st option by parsing on "("
															// (first option has name specific to each `cmd' but is always first option)
	
	local opt1 = lower("`preparen'")						// Deal with capitalized initial chars for this option name
															// (leaves the lower case version of 1st optn in 'opt1', referenced below)
															

	
	
	
global errloc "wrapper(0.2)"
pause(0.2)	
															
															
										//*******************************************************************************************
										// (0.2) Cycle thru components of pre-mask command string, dividing it into 'varwtopt' chunks
										//*******************************************************************************************

										
	local keep = ""											// will hold `wtexp' 'opt1' plus contextvars, itemname, stackid, etc.
	local varlists = ""										// Empty the list of varlists accompanying each specific option-list
															// (first varlist may include `ifinwt'; later ones only `wt', if present)
	gettoken preopt anyopt : cmdstr, parse(",")				// Local `anyopt' is empty if there's no optionstring anywhere in `cmdstr'
	if "`anyopt'"==""  {
	  if `needopts'   {										// `needopts' was preset in 0.1 to flag whether options are required for `cmd'
		errexit "This command requires one or more options" // **************************************************************************
		exit 1												// Local anyopt should hold `opts' for first varlist (or for final varlist if
	  }														//  previous varlsts have no `optlist's). So `anyopt' may provide options for
	}														//  those earlier varlists if none have an optlist; or will be overwritten by 
															//  earlier optlist when those are processed again in coming 'while' loop.
															// Else varlist(s) with code 0 in `needopts' indeed have none
															// **************************************************************************
	if "`anyopt'"!=""  {
	   local anyopt = strtrim(substr("`anyopt'",2,.))		// `anyopt' has leadng comma (from 'gettoken', above) that must be trimmd off
	   gettoken anyopt tail : anyopt, parse("||")			// `tail' is empty if `anyopt' is only optlist or appended to final varlist
	}														// (either way `anyopt' is there if needed below; meanwhile we start over)
	if "`tail'"!="" & "`cmd'"=="genmeanstats" {
	   errexit "genmeanstats expects just a single varlist but cmdline contains/ends with '||'"		
*				12345678901234567890123456789012345678901234567890123456789012345678901234567890
	}
	
	
	
	
	local varwtoptlst = ""									// Empty list of `varwtopt's (`cmdstr' brokn into separte str for each varlst)
	
	local optlst = ""										// Empty the list of user-specified options for this varlist
															// (may be supplied by final optlst if pervious optlists are empty)
	local nvarlst = 0										// Count of individual varlists (there may be any number of these)
															// (`nvarlst' is incrmentd at the 'next while' close brace just before blk 2)
	local origmask = strtrim("`mask'")						// `mask' will morph below from original prog-defined to `cmd'-specific
															// (so must keep a copy of the original version before it morphs)
	
	
	
*	***********************
	while "`cmdstr'"!=""  {									// While `cmdstr' is not empty (`cmdstr' is what the user typed from blk 0.1)
*	***********************									// (is empty followng the final `cmdstr' & we use that as a flag here & below)

	   local nvarlst = `nvarlst' + 1						// Increment # of varwtopt strings
	   
	   gettoken thistr cmdstr : cmdstr, parse("||")			// Isolate `thistr' as actionable string in (possible set of) varwtopts	  
	   local cmdstr = strtrim(substr("`cmdstr'",3,.))		// Trim off the leading "||" in remains of `cmdstr'
															// (`cmdstr' is left empty if this was the final such string of this command)
															// (used as flag twice below to determine error conditions)
	   gettoken varwts opts : thistr, parse(",")  			// Save vars & wts in `varwts' (ends before "," or at end of command string)
															// (cannot use local named `options' as that gets overwritten by syntax cmd)
	   if strtrim("`opts'")==","  {							// If comma has no following text..
	   	  errexit "Comma was not followed by list of options"
		  exit 1
	   }
	   local raw_opts = strtrim("`opts'")
	   if substr("`raw_opts'",1,1) == ","  local raw_opts = strtrim(substr("`raw_opts'",2,.))
	   char define _dta[OPTIONS`nvarlst'] "`raw_opts'"		// Here save options from this cycle (saved to avoid overrwriting)
															// (thank you Claude – saved where 'getprfxdvars' expects to find them
	   if substr("`opts'",1,1)==","  local opts = (substr(strtrim("`opts'"),2,.)) // Trim off leading comma & any blanks at head of `opts'
	   if "`opts'"==""  {									// If there is no comma (& thus no opts) following the current varlist..
		  if `nvarlst'>1 & "`prevopt'"!=""  {				//  check if prev varlist was followed by a comma and options (flagged below)
		  	  errexit "Previous varlist was followed by ', optionlist' so this varlist needs the same"
*					  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  exit 1
		  }
		  if strtrim("`cmdstr'")=="" & `needopts' {			// If `cmdstr' is empty (at end of command) and `needopts' flag was set non-0
			 errexit "Final varlist must end with optlist, so it can supply previous varlsts w options"
*					  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			 exit 1
		  }													// Otherwise cmdstring is valid
	   	  local varwtopts = "`varwts', `anyopt'" 			// As this varwtopts-list contains no opts, append `anyopt' from pre-`while'
		  local optlst = strtrim("`anyopt'")				// (will be added to `varlists' before next 'while' in codeblk 1.2)
			
		  if "`tail'"!=""  {								// If `tail' is not empty we have a syntax error as
		  	  errexit "Either all varlsts should have optlists or final optlist shld supply all varlsts"
*					   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  exit 1
		  }
	   } //endif `opts'
	   
	   else  {												// Else `opts' is not empty; so it contains ", option-list"
		  if `nvarlst'>1 & "`prevopt'"=="" {				// Check if prev varlist (if any) was followed by optlist
		    if strtrim("`cmdstr'")!=""  {					// If there were no options on previous varlist & this is not final optlist..
				errexit "As prev varlist had no option-list this next one, if not final, also should not"
*					     12345678901234567890123456789012345678901234567890123456789012345678901234567890
				exit 1
			}
		  } //endif `nvarlst'
		  
		  if `needopts'  local prevopt = "yes"				// Set `prevopt' flag, if needopts, for benefit of next `thistr' (set above)
		  local varwtopts = "`varwts', `opts'"				// Append `opts' to `varwts' and to `optlst'
		  gettoken varwts opts : varwtopts, parse(",")		// On 2nd and subsequent varlists need to parse on (","); won't affect 1st
		  if "`opts'"!=""  local optlst = strtrim("`opts'")	// (so `varwtopts' gets own optlist if it did not get final optlist pre-'else')		  
	   } //endelse											
	   
	   
	   **********************								
	   local 0 = "`varwtopts'"								// Either way, put what was found into local 0 where 'syntax' looks for it
*	   **********************								// (local 0 is established here for use when processing each varwtoptlist)
															// (correspondng `mask' will be culled of unused optns in next codeblk, 0.3)
															// (corresponding 'syntax' command is in codeblk 0.4, below)
															
															
															
global errloc "wrapper(0.3)"																
pause(0.3)

										// (0.3) Process the options-list for each varwt-optlist pair established in 0.2, above
										// 	   (some code supporting multiple optns lists is retaind in case of a future elaboration)
															
															// ************************************************************************
															// In codeblk 0.3 we will elabrate the `mask' from caller program to include
															// additional options common to all stackMe commands. We will then cull the 
															// mask of all elements that were not user-optioned for the current varlist 
															// and rebuild the global mask to include only elements that were actually 
															// optioned for this varlist. 
															//  The reconstructd mask will be put in char MASK`nvl' whose numeric suffix
															// identifies which varlist needs that mask; so a syntax command executed 
															// later in this wrapper or in a subprogram can use a mask tailored to the
															// command-string actually used (or implied) for that varlist, eliminating
															// wasted attmpts to match an option with maybe tens of unused mask elemnts 															// for perhaps thousands of stacks X contexts.
															// ************************************************************************
		
										
	   if substr("`opts'",1,1)==","  {  					// If `opts' (still) starts with ", "
		  local opts = strtrim(substr("`opts'",2,.))		// Trim off leading ", "  (`opts' were parsed in 0.2 above)
	   }													// (`opts' gets new values below as a flag that controls parsng of `optlst')
															// (`optlst' has phantom option-strs from final varlst if earlier had none)
	   
															// Following code has successive optlists updating active options for each
															// Initial `mask' (coded in the wrapper's calling program) was pre-processed
															//  in codeblock 0.2 above); options added here apply to all stackMe commads
*	   														// (except that genstacks cannot have NOCONtexts or NOSTAcks)
	   ***************
	   local mask = strtrim("`origmask' NODiag EXTradiag APRefix(str) CONtextvars(varlist) NOCONtextvars NOSTAcks SPDtst")
*	   ***************										// Append to `origmask' (from block 0.2) additional opts common to all cmds
*	   local savmask = "`mask'"								// CLUGE ATTEMPTS TO KEEP BACKUP COPY, SINCE MASK GOES MISSING BEFORE 0.4		***
															// (`limitdiag', common to all `cmd's, is in each caller, flagging last arg)
															// (option SPDtst uses simpler append-file code – apparently slower)
*	   ****************								
	   syntax [anything] [if] [in] [fw aw pw iw/] [, `mask' * ] 
*	   ****************										// Matches what user typed (put in "`0'" at end of 0.2) with extended `mask'
															// (final asterisk in 'syntax' places unmatched options in `options')
	   if "`options'"!=""  {								// Here check for user option(s) that don't match any listed above
		  dispLine "Option(s) invalid for this cmd: `options'{txt}" // Display what might be message of more than one line
		  errexit, msg("Option(s) invalid for this cmd: `options'") // Call on 'errexit' with optioned msg suppresses 2nd display
		  exit 1											// 'exit' cmd returns to caller, skipping rest of wrapper incldng skipcapture
	   }													// ABOVE 'syntax' GETS DEFAULTS FROM ADDED OPTIONS EVEN IF NOT USER-OPTIONED

	   local usrmsklist = ""								// Initialize `usrmask' that will hold only user-optioned syntax components
	   local upusrmask = ""									// Initialize list of above options with first three chars in upper case
	   local maskerr = ""									// Initialize list of user errors due to bad option naming
	   local arglist = ""									// Initialize list of user-specified arguments is empty ditto
	   local optlist = ""									// Initialize list of user-specified options with parnthszd arguments if any
	   local optnmlist = ""									// Initialize list of user-specified optnames without arguments
	   local upusrmsklist = ""								// Initialize list of mask elements, with parenthsd descriptors, if any
															// (and upper-case first three chars of optname)
															// MAYBE MORE OF THE ABOVE THAN ACTUALLY IN USED							***
	
	   
*	   *********************	   							*************************************************************************
	   while "`opts'"!=""  {								// Loop over `opts' while the list of user-invoked options is not empty..
*	   *********************								*************************************************************************

		  local args = ""									// Ensure local w' arguments for any opt is empty in case `opt' has no args

		  local opts = strtrim(stritrim("`opts'"))			// Ensure `opts' have no excess spaces before or after or between `opts'
		  
															
		  gettoken istwrd rest : opts						// FIRST SEE IF `opts' STARTS W AN OPTNAME WITHIN 1ST, SPACE-DELIMETED, WORD
		  
		  gettoken optnm post : istwrd, parse( "(" )		// If an open paren is in that space-delimited word, then argument follows
															// And we have an option-name in `optnm', so long as `post' is not empty
		  if "`post'"!=""  {								// If there is a `post'-parenthesis text string, it starts with "("
		    local post = substr("`post'",2,.)				// So trim that off in case Stata mistakes it as introducing a function call
															// (thank you Claude)
		    gettoken optarg aftr : istwrd, parse( ")" ) 	// See if a one-word option also contains a one-word parenthesized argument
			if "`aftr'"!=""  {							 	// (would begin w "`optnm'(`args'" & end w ")" as last charctr of "`istwrd'"
			  gettoken optnm args : optarg, parse( "(" )	// Split `optarg' into `optnm' and `args', parsing on an open parenthesis
			  local args = strtrim(substr("`args'",2,.))	// And trim leading "(" from `args' (PLURAL NAME EVEN THO' ONLY ONE ARG)
															// (`args' does not have final ")" because that was not included in `optarg')
			  local optlist =  "`optlist' `optnm'(`args')"	// Add to list of optargs within artful parens isolating paren from argname
															// (thank you Claude)
			  local opts = strtrim(substr("`rest'",2,.))	// Then, again from 'gettoken istwrd..', `rest' has remaining `opts', if any
			} //endif										
												
			else  {											// Else option is not complete within first word
			  gettoken optnm next : opts, parse( "(" )		// Adapt 2nd 'gettoken' above so `post'->`next' can extnd over multiple wrds
			  if "`next'"!=""  {							// If not empty..
				local next = strtrim(substr("`next'",2, .)) // trim leading "(" from `next'; then look for matchng close paren
			    gettoken args opts : next, parse( ")" )		// After the ")" what remains are whatever additional `opts' there may be
				if "`opts'"==""  {							// If `opts' is empty the close parenthesis is missing, a syntax error
				  errexit "Missing close parenthesis for user-optioned `usropt'"
				  exit 1		  
			    }											// Else `opts' isn't empty (don't need 'else' clause due to 'exit 1' above)
			    local opts = strtrim(substr("`opts'",2,.))	// The `opts' string starts with ")", so trim that off;  `args' is clean
				local optlist = "`optlist' `optnm'(`args')" // Add optargs to optlist within artful parens, as above (thnks again Claude)
			  }	//endif `next'								// (left-over `opts', if any, are options to be processd during later loops)
		    } //endelse `aftr'								
		  } //endif `post'									 
		  
		  else  {											// Else `post' has no open paren so it contains an ON-type option (a "flag")
		    local optnm = "`istwrd'"						// Lacking an open paren, `istwrd' (found by initial 'gettoken') is `optnm'
		  	local opts = "`rest'" 							// And `rest' (from the same 'gettoken') goes into `opts', still to process
			local optlist = strtrim("`optlist' `optnm'")	// Append to list of already-processed `optnm's 
		  }
		
		local arglist = strtrim("`arglist' `args'")			// Append to list of `args'
		
		
															// NEXT PRE-PROCESS COMPONENTS OF AN ABBREVIATED 'syntax' COMMAND
															// (abbreviated in that it is limited to optnames that were user-optioned)
															
															// A new `submask' is prpared for each `opt' in the list of user-optnd `opts'
*		  ********************************************************************************	// (containing only optioned syntax elemnts)		  
		  local submask = substr(lower("`mask'"), strpos(lower("`mask'"),"`optnm'"),.)+" "  // Start the `submask' w head of `optnm' and 
*		  ********************************************************************************	// end with added space (it may be parsd on)
															// (each submask starts with user-selectd optname, plus descriptor if any)
															// (THE WHOLE ELEMENT – WITH OR WITHOUT DESCRIPTOR – IS HELD IN ONE WORD)
															
		  gettoken submask rest : submask					// Put in `rest' (discarded) remains of submask following that 1-word elemnt
															// (because it comes from `mask', the optname is fully spelled out)
		  local dscrp = ""									// If user-specified option has no descriptor we need `dscrp' to be empty
		  
															// HERE REPEAT LOGIC USED FOR OPTIONS, ABOVE, BUT W' `OPTNS OF ONE WORD EACH
															// (unlike with options, there can be only one descriptor per optname)
		  gettoken optnm dscrp : submask, parse( "(" )		// Both `optnm' & `dscrp', if any, will be in first (only) word of `submask'
															// First extend list of `optnm'`args' using full `optnm' from `mask'
		  local upoptnm = strupper(substr("`optnm'",1,3)) +substr("`optnm'",4, . ) // Make 1st 3 charctrs upper case ('stackMe' standard)
															// (since `optnm' ends with a space, "." takes us to end of that word)
		  if "`dscrp'"!=""  {								// If `dscrp' is not empty then `dscrp' starts with "("
															// (`dscrp' has fully unabbreviated name of descriptor, following that "("
			if substr("`dscrp'",-1,1)!=")"  {				// If `dscrp' has no close parenthesis that's a syntax error
			  errexit "Missing close parentheses for syntax descriptor `dscrp'"
			  exit 1										
			}												// At this point `dscrp' starts and ends with open and close parentheses
															// (they don't need to be isolatd from descrptr-name as that is not a local)
			if !strpos("`upusrmsklist'","`upoptnm'`dscrp'") local upusrmsklist ="`upusrmsklist' `upoptnm'`dscrp'" // If not alredy there,
															// append new `mask' element, `upoptnm..crp', with 1st 3 chars in upper case				
		  } //endif `dscrp'									// (NOTE: previous, prhps abbreviatd, versn of `optnm' is alrdy in `optlist') 
		  															
		  else  {											// Else there is no syntax descriptor so option is an "optionally ON"-type 
		  	if ! strpos("`upusrmsklist'","`upoptnm'") local upusrmsklist = "`upusrmsklist' `upoptnm'" // If not alredy in `upusrmsklist',
		  } // endelse)	  upusrmsklist						// append new `mask' element, `upusrmask', with 1st 3 chars in upper case	
		  		  
				  
															// NOW WE KNOW WHAT IS THE FULLY SPELLED-OUT `optnm',..
															
															// If it is the var that `opt1' points to, we can update the `opt1' argumnts
		  if "`opt1'"==substr("`optnm'",1,strlen("`opt1'")) { // `opt1' only has what user typed, which was perhaps abbreviated
			if "`prfxtyp'"=="var"  {						// `opt1' always has arguments, placed in `arglist' before 'local submask'
															// If those args are varnames we need to check that those vars exist
															// *************************************************************************
*			  *******************************				// Cmd 'unab' balks at some varlists w both hyphenated and abbreviated vars. 
			  checkvars "`args'"							// CHECKVARS unabs the vars in 'args', also dealing with hyphenated varlists
			  if "$SMreport"!=""  exit 1					// Checkvars reports errors directly to 'errexit' unless 'noexit' is argued.
*			  *******************************				// 'exit' cmd returns to caller, skippng rest of wrappr includng skipcapture
															// $SMreport is only set by errexit, signalling error IN `args'.
			  local args = r(checked)						// *************************************************************************
			  local keep = "`keep' `args'"
			}												// Whether vars or strs, args can now be put in local that `opt1' points to
		  	local `opt1' = "`args'"							// (assigning them to what `opt1' points to will overwrite `opt1's args; but,
		  } //endif `opt1'									//  if those were abbrevtd varnames, they were just 'unab'ed by 'checkvars',
															//  making these the appropriate versions to put into `opt1'

															
		  local raw_options : char _dta[OPTIONS`nvarlst']	// HERE RECOVER VERSION OF `options' SAVED FROM OVERWRITNG IN 0.2) 
															// (thank you Claude – even if I don't really understnd how this works)
															
*		*********************
		} //next while `opts'	 							// (`dscrp' is empty if there is just one ")"-delimited descriptor, or none
*		*********************								// (this 'while' loop starts near top of this codeblk – 0.3)


															// ********************************************************
															// Examination of command structure continues to end of 0.4
															// ********************************************************
															
															
*		********************								// AS YET UNTESTED SUPPOSITION FOLLOWS...									***							
*		if "`cmdstr'"!=""  {								// Perhps shld not execute followng lines if we get here after last `cmdstr'
*		********************								

		
*		  **********************************************	// Save revisd `optlist', holding only optioned & expanded optnames w args
		  char define _dta[OPTLIST`nvarlst'] "`optlist'"	// (constructed in pre-submask codeblk)
		  char define _dta[MASK`nvarlst'] "`upusrmsklist'"	// Save revisd `mask' in char MASK`nv..', holdng optd elemnts for this varlst
		  char define _dta[VARSTUBS`nvarlst'] "`args'"		// Save args as stubnames (for gendummies)
*		  **********************************************	// (minimizes processng time for `syntax' commnds executed for each context)
															// HERE _dta[MASK] MORPHS INTO `upusrmask' SO ALL SUBPROGS CAN ACCESS THAT
															// (`upusrmask' has only user-optioned mask elemnts with 1st 3 chars upper)
	      if "`maskerr'"!=""  {
	   	    errexit "Invalid user-typed option name(s): `usropt'"
		    exit 1											// (we do not check contents of parentheses, if any)
	      }
															// NOTE: 'opt' 'opts' and `optlst' are different locals
*		******************	   
*	    } //endif `cmdstr'									// DELETE COMMENTING-OUT ASTERISKS, ABOVE & BELOW, TO TEST ABOVE SUPPOSITION ***																			***
*		******************	   
	   
	   
	   
	   
		
global errloc "wrapper(0.4)"																
pause(0.4)
										// ***********************************************************************************
										// (0.4) Short codeblock that checks for user-specified options on later varlists that
										//		 are only permitted on the first of any set of varlists
										// ***********************************************************************************

																	
				
				
														
*		***************										//*****************************************************************
		if `nvarlst'>=2  {									// IF THIS IS 2ND OR LATER VARLIST, SOME OPTS/EXPRESSN ARE EXCLUDED
*		***************										//*****************************************************************

										
		  local nw = wordcount("`varwtopts'")				// No easy way to check for 'if' and 'in' expressions
		  forvalues i = 1/`nw'  {
		  	local wrd = word("`varwtopts'",`i')
			if strlen("`wrd'")==2 & ("`wrd'"=="if" | "`wrd'"=="in")  {
			  errexit "'if' and 'in' expressions not allowed after first varlist of multi-varlist cmd"
*		               12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  exit 1
			} //endif
		  } // next `i'
		
		  if strpos("`optlist'","contextvars")  {		// If `strpos' returns !0 for "contextvars"
			errexit "Option 'contextvars' not allowed after first varlist of multi-varlist command"
			exit 1
		  }
			 
		  if strpos("`optlist'","stackid")  {			// If `strpos' returns !0 for "stackid"
			 errexit "Option 'stackid' not allowed after first varlist of multi-varlist command"
			 exit 1
		  }
			 
		  if strpos("`optst'","nostacks")  {			// If `strpos' returns !0 for "nostacks"
			 errexit "Option 'nostacks' not allowed after first varlist of multi-varlist command"
			exit 1
		  }
			 
		  if strpos("`optlist'","nocontextvars")  {	// If `strpos' returns !0 for "nocontextvars"
			errexit "Option 'nocontextvars' not allowed after first varlist of multi-varlist command"
*		             12345678901234567890123456789012345678901234567890123456789012345678901234567890
			exit 1
		  }
	

	
*		**********************		  	   				// *****************************************************************************
		} //endif `nvarlst'>=2							// Else, after this `endif', we examine those =1 then all varlsts undistinguishd
*		**********************							// *****************************************************************************
															
		
		
		
		
		
global errloc "wrapper(1)"		
pause(1)

										// *********************************************************************************************
										// (1) IN THIS AND FOLLOWING CODEBLKS WE PROCESS INDIVIDUAL OPTNAMES ACTUALLY OPTIONED BY THE
										//	   USER, LOOKING AT CONSEQUENCES OF THE CHOICES USERS MADE. We start with a 'contextvars' 
										//	   option/characteristic as first instance of optioned variables that need to be kept in the
										//	   active data subset; other vars are dropped so active data can be more efficently managed
										//	   (e.g. swapped in and out of memory, behind the scenes).
										// *********************************************************************************************
										
*		******************
		if `nvarlst'==1  {								// `contextvars' are only addressed in connection with first varlist
		******************
					 		  
		  local stackid = "`SMstkid'"					// Local 'stackid' cannot be optioned in v2, so is used within wrapper
														// (as it was in version 1, for many flagging purposes)
		  if "`nostacks'" != ""  local stackid = "" 	// But treating stacked data as unstacked is still possible						***
														// (except in genstacks, where it is treated as an error – see 'cmd'O)

										
	      local initerr = ""							// local will flag lack of established contextvars
	      local optadd = ""								// local will hold names of optioned contextvars to add to keepvars
		  
		  local usercontxts = "`contextvars'"			// To avoid being confused with contextvars from data characteristic
														// (use wordy 'usercontxts' for optioned contextvars, empty if none)		  
		  
*		  ****************************************		// Implementing a 'contextvars' option involves getting charactrstic
		  local contexts :  char _dta[contextvars]		// Retrieve contextvars charctrstc established by SMsetcontexts or prior 'cmd'
*		  ****************************************		// (not to be confused with 'contextvars' user option)
														// (lower case since se in SMsetcontexts & not cleared by next stackMe command)

		  global contextvars = "`contexts'"				// This global is used by 'genstacks' and perhaps other stackMe commands
		
		  noisily display "{txt} "						// Insert a blank line if diagnostics are to be displayed
		
		  if "`contexts'"!=""  { 						// Characteristic HAS been initialized
														
			  if "`contexts'"=="nocontexts"  {			// Contexts were defined as absent by SMsetcontexts
			     noisily display ///
			     "{txt}NOTE: stackMe utility {help stackme##SMsetcontexts:SMsetcontexts} defined this dataset as having no contexts{txt}"
*		              12345678901234567890123456789012345678901234567890123456789012345678901234567890
			     local contexts = ""					// Make it empty so we don't take "nocontexts" to be a variable name!
			  }              							// Will be displayed after end of 'limitdiags' codeblock
			  
														// (FOR EXTENDED PURPOSE & WORKING OF 'checkvars' SEE END OF CODEBLK 0.3)
*			  *******************************			// Cmd 'unab' balks at some varlists w both hyphenated and abbreviated vars 
			  checkvars "`contexts' noexit"				// Unab the vars in 'contexts', also dealing with hyphenated varlists
			  if "$SMreport"!=""  exit 1				// Checkvars reports errors directly to 'errexit' unless 'noexit' is argued
*			  *******************************			// 'exit' cmd returns to caller, skipping rest of wrappr including skipcapture
														// $SMreport is only set by errexit, signalling contextvars error
														// THIS CHECK SHOULD HAVE BEEN CONDUCTED IN 'SMsetcontextvars'					***

			  local errlst = r(errlst)					// Returned by 'checkvars' (checkvars also returns r(checked))
			  if "`errlst'"=="."  local errlst = ""		// SEEMINGLY r(errlst) RETURNS "." RATHER THAN ""								***
			  if "`errlst'"!=""  {						// If there are any such...
				  dispLine "This file's characteristic names contextvar(s) not in dataset: `errlst'{txt}" "aserr"
				  display as error "Use utility command {help stackme##SMsetcontexts:SMsetcontexts} to establish valid contxtvars{txt}"
*		                 		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  errexit, msg("This file's contextvars charactrstic names variable(s) that don't exist: `errlst'")
				  exit 1								// (if errext msg is an option not an argument 'errext' does not display it)
			  } //endif

			  else  {									// Else data characteristic holds valid contextvars
				  noisily display "Established contextvar(s): `contexts'{txt}" 
			  }
			  
			  if "`usercontexts'"!=""	{				// If user optioned `contextvars' for current `cmd' ..
			    local same :list contexts===usercontxts // Returns 1 in `same' if two strings match (even if ordered differently)
				if `same'  noisily display  "NOTE: redundent 'contextvars' option duplicates established contexts{txt}"
					
				if !`same'  {							// Else strings don't match
					if "`cmd'"=="genstacks"  {
					   local txt = "Contextvars option contradicts established contexts '`contexts''"
					   capture window stopbox rusure  "`txt'; continue with established contexts?'"
*		          				 1234567890123456789012 3456789012345678901234567890123456789012345678901234567890
					   if _rc  {
					   	  errexit "Lacking permission to ignore optioned contexts"
						  exit 1						// Non-zero return code tels us user did not click 'OK'
					   }
					} //endif `cmd'==`genstacks''
				 
					else  {								// Else cmd is not genstacks
					  local txt = "Contextvars option contradicts established contexts"
*		          				   12345678901234567890123456789012345678901234567890123456789012345678901234567890
					  noisily display "`txt'; continue with optioned contexts?"
					  capture window stopbox rusure  "`txt'; temporarily replace(s) established data characteristic?"
					  if _rc==0  {
					    noisily display "Optioned contextvar(s) temporarily replace(s) established data characteristic" 
					    local contexts = "`usercontxts'"
				      }
					  else  {							// Else user does not respond with 'ok'
					    errexit "Lacking permission to temporarily replace established contexts will exit on 'OK'"
*		          				12345678901234567890123456789012345678901234567890123456789012345678901234567890
					  }

				    } //endelse `cmd'=='genstacks'
			
			    } //endif !`same'
		  
			  } //endif `usercontxts'
			
	      } //endif `contexts'!=""						// The next check involves an actual error that terminates execution
			
			
		  else  {										// Else _dta[contextvars] characteristic was empty
		  
			  local display as error  /// 				
			  "stackMe utility {help stackme##SMsetcontexts:SMsetcontexts} hasn't initialized this dataset for stackMe"
*		                              12345678901234567890123456789012345678901234567890123456789012345678901234567890
		      errexit, msg("Use stackMe utility SMsetcontexts to define the dataset's contexts")
			  exit 1
				
		  } //endelse


		  if "`usercontxts'"!=""  {						// If there are user-optioned contextvars for dtaset w established cntxts
		  
			  	
*			  *************************					// (FOR ACCOUNT OF PURPOSE & WORKING OF 'checkvars' SEE END OF CODEBLK 0.3)
			  checkvars "`usercontxts'"					// Just in case these contain a hyphenated varlst 
			  if "$SMreport"!="" exit 1					
*			  *************************
			  local contextvars = r(checked)

			
			  if "`cmd'"!="genstacks"  {				// If this is not a genstacks cmd

			    noisily display "This command's contextvars options will temporarily govern this command. Ok?"
				capture window stopbox rusure "This command's contextvars option `usercontxts' will temporarily govern this command. Ok?"
				if _rc  {
				   errexit "lacking permission for temporary change in contextvars"
				   exit 1
				}
			  
			  }
			  else  {									// Else this is a genstacks command
			    display as error "stackMe utility {help stackme##SMsetcontexts:SMsetcontexts} should initialize this dataset for stackMe"
*		                                12345678901234567890123456789012345678901234567890123456789012345678901234567890
		        errexit, msg("Use stackMe utility SMsetcontexts to define the dataset's contexts")
			    exit 1
			  }
			  
			
		  } //endif 'usercontxts'
										
		   
														
														
*		**********************							// ****************************************************************************
		} //endif `nvarlst'==1							// NEXT SEVERAL CODEBLOCKS CONTINUE TO EVALUATE SUBSTANTIVE CONSEQUENCES OF THE
*		**********************							// OPTION CHOICES MADE BY USERS.
														// ****************************************************************************
														
														
														
														
	
	
	
global errloc "wrapper(1.1)"
pause(1.1)
										// ********************************************************************************************
										// (1.2) Still processing current varlist, deal with first option (the only option identifiable 
										//		 by position as well as by name). The content of that option may be a varname/varlist
										//		 (if the pre-`mask' `prfxtyp' flag is "var") or a string/name if the `prfxtyp' is `othr'.
										//		 A third type ("none") is not currently populated (see 0.1). This codeblk also deals 
										//		 with references to SMitem and `itemname'.
										// *********************************************************************************************
														
		
		local optad1 = ""								// Will hold indicator or cweight options (REMOVE IF VERSION 10 RUNS WITHOUT)	***
	
		local opterr = ""								// Reset opterr 'cos already dealt with previous set of error varnames

														// In the general case 'opt1' has name if first option in 'optMask' (0.2)
		if "`cmd'"=="genplace"  {						// But if this is as a 'genplace' command varlst could have 1 of 2 names
		
			local indicator = "``opt1''"				// Move associated var(list) from `opt1' to `indicator'
		    local opt1 = "`indicator'"					// Put the 'genplace' optname "indicator" into `opt1'
		    if "`wtprefixvars'"!=""  {					// If `wtprefixvars' was optioned...
			  local cweight = "``opt1''"				// Put the 'genplace' optname associated varlist from `opt1' to `cweight'
		   	  local opt1 = "`cweight'"					// Have 'opt1' contain the 'genplace' optname of that var(list)
		    }											// So, just as tho it had been first in the optMask
		}												// Above code repeats code used in 0.2 for subsequent varlists
		

		if "`itemname'"!=""  {							// User has optioned an SMitem-linked variable
		    capture confirm variable `itemname'
		    if _rc  {
		      errexit "Optioned 'itemname' is not an existing variable"
			  exit 1									// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
		    }											// If 'itemname' survives this check it will be added to 'keepoptvars'	
			else  {
			  local optadd = "`optadd' `itemname'"
			  char define _dta[SMitem] "`itemname'" 	// This itemname is stored in a data characteristic
			}
		} //endif `itemname'
		  

		if "`keep'"!=""	 {								// If `keep' is not empty then it already has `opt1' vars, from codeblk 0.3
														// (the only var-related option with chance of having been processed)
														
		  if "``opt1''"!="" & "`prfxtyp'"=="var" {		// If first option names a variable(list)
		
*	  	    *****************************				// (FOR EXTENDED PURPOSE & WORKING OF 'checkvars' SEE END OF CODEBLK 0.3)
		    checkvars "``opt1''"						// Double quotes get us to the varname(s) actually optioned
		    if "$SMreport"!="" exit 1					// ($SMreport is empty if return code of 0 was reported)
*	  	    *****************************				// 'exit' cmd returns to caller, skipping rest of wrappr, incldng skipcapture
		    local checked = r(checked)

		    foreach var  of  local checked  {			// opt1 is a varlist (established by 'if' that initiates this codeblk)
		      capture confirm variable `var'			// Here get list of unconfirmed varnames
		      if _rc  local opterr = "`opterr' `var'"	// (in 'opterr) // ANOTHER EXAMPLE OF 'else' ERROR WITH ADJACENT 'if' & 'else'	***
			  else  {									// ADDED THIS OPEN BRACE TO AVERT THE ERROR										***																	***
		      /*else*/ local optadd = "`optadd' `var'"	// Else add var to list of those in `opt1' that need to be kept in working data
			  }											// ADDED THIS CLOSE BRACE TO AVERT THE ERROR									***		
		    } //next 'var'
		   
		    if "`opterr'"!=""  {
			  dispLine "Variable(s) named in option `opt1' not found: `opterr'"  "aserr"
			  errexit, msg("Variable(s) in 'opt1' not found – see displayed list)"
			  exit 1									// Comma stops msg being displayed on output
		    }											// 'exit' cmd returns to caller, skipping rest of wrappr, incldng skipcapture
		 
		  } //endif ``opt1''							// ABOVE MAY BE REDUNDANT IF ALREADY DONE IN `checkvars'						***
		  
		  
		  else  {										// Else `opt1' does not hold a var(list)		
		  	if "``opt1''"!="" & "`prfxtyp'"=="othr"  {  // `opt1' may hold stubnames for 'gendummies' (eg. local stubs == stubnames)
*			 	local `opt1' = "``opt1''" 				// (`opt' may also hold "othr", but that opportnty appears not to have been used)
			}											// (COMMENTED OUT `COS SUPPOSED SIMPLIFICATION IS PROBABLY TOO RISKY)
			
		  } //endelse ``opt1''							// ******************************************************************************
														// NOTE: WHILE `opt1' IS NAME OF OPTN, ``opt1'' IS WHAT USR OPTNED W' THAT OPTNAM							
														// ******************************************************************************
		} //endif `keep'
		
local show = "`opt' -> ``opt''"

		local keepoptvars = strtrim(stritrim("`contextvars' "+  /// Trim extra spaces from before after and between names to be kept
			  "`keep' `optadd' `optad1' `itemname'"))  			// Put all these option-related variables into keepoptvars 
																// (SMstkid and other stacking identifiers will be handled separately)
																// (`itemname' can be referenced only by using this alias)		
		local varwt = strtrim("`varwt'")
		if substr("`varwt'",-1,1)==","  local varwt = strtrim(substr("`varwt'",1,strlen("`varwt'")-1))
		**************************************
		local varwtopts = "`varwtopts' `varwt'"					// 	varlists' was initialized near start of codeblk 0.2
		local varwtoptlst = "`varwtoptlst' `varwtopts' ||"		// `varwtopts' was constructed from `cmdstr' near start of codeblk 0.2
		*************************************					// (the first varwtopts) may include an 'if' or 'in' expression)

	  
*		********************
		local optnmlist = ""									// BLANK OUT ANY OPTNAMELIST THAT MIGHT NOT BE REPLACED BY NEXT OPTLIST
		********************
		
/*																// COMMENTED OUT AS SEEMINGLY NOW DONE EARLIER IN WHILE LOOP	  
		if "`cmdstr'"!="" { 
		   local cmdstr = strtrim(substr("`cmdstr'"),3,.)		// Trim leading "||" and possible space(s) from head pf remaining `cmdstr'
		}														
*/		
	  
	***********************
	} //next while `cmdstr'										// Repeat for next varlist in `cmdstr' (if any)
    ***********************										// (this while loop starts near top of codeblk 0.2)
																//  leaves us with those `option(s) governing this (set of) varlists

	if substr(strtrim("`varwtoptlst'"),-2,2)=="||"  {			// Strip off any pipes terminating final `varwtoptlst' in 'varwtoptlsts')
	   local varwtoptlst = strtrim(substr("`varwtoptlst'",1, strlen("`varwtoptlst'")-3))
	}
	
	local multivarlst = "`varwtoptlst'"							// Legacy code expcts multiple varlsts to be accumulatd in `multivarlst'
																// (`multivarlst' was initialized in codeblk 0.2)
	
	
	
	
	
local show = "`opt' -> ``opt''"
	

global errloc "wrapper(2)"	
pause(2)

															

										// ******************************************************************************************
										// (2)  HAVING FINISHED PROCESSING THE OPTIONS THAT MAY OR MAY NOT FOLLOW EACH VARLIST,
										//		this codeblk again extracts each varlist in turn from the pipe-delimited `varwtoptlst'
										//		local established at the end of codeblk (0.2) and, after sorting the variables into
										//		input and outcome lists, pre-processes if/in/weight expressns for each varlist, then
										//		re-assembles those varlsts, shorn of 'ifinwt' expressns, into a new multivarlst that
										//		can be passed to whatever 'cmnd'P is currently being processed, after creating a work-
										//		ing dataset containing only user-selected vars and observations.
										// ******************************************************************************************
	
															// Here we process multivarlst for all cmds (including genstacks)
	local nvl = 0											// Reset # of varlist to 0 so as to count varlists from scratch, below
	local lastvarlst = 0									// By default current varlst is not the last one in a multivarlst command
	global genstkvars = "`multivarlst'"						// Cluge helps to deal with genstacks having two varlist formats
	char define _dta[GENSTKVARS] "`multivarlst'"			// Will be reset =1 when final varlist is identified as such
	local outcomes = ""										// Varnames that will provide string-prfxed outcome varnames (see 2.1)
    local inputs = ""										// Only for 'genyhats' does one of these morph into an outcome varname
															// (otherwise, 'inputs' will hold names of supplementary input vars)
	local prfxvars = ""										// Varnames that appear as prefix to varlist (prfxvars end w colon)
	local strprfx = ""										// Prefix string (max 1 per varlst) can help distngush between varlsts
	local keepwtv = ""										// Up to 2 (hopefully identified) weight vars to be kept in (2.2)	
	local errlst = ""										// List of supposed varnames found not to exist
	local opterr = ""										// Used repeatedly to collect list of erronious options/varnames
    local ifvar = ""										// Optionally filled later in this codeblk: var associated w 'if' exp
	local wtexplst = ""										// Optionally filled later in this codeblk: the weight expression
	local stub = ""											// Optionally ditto: dummy variable stubname(s)
	local gotat = ""										// Ditto for `gotat' (FLAG SIGNALLING EXPERIMENTAL SYNTAX yh@ PREFIX)
															// (WILL BECOME _dta CHARACTERISTIC FLAGGING 'yh@' PRFX, if IMPLEMENTD)		***

	
	   *******************************************************************************************************************************
	   *																															 *
	   *	   varlists --> anything --> inputs&outcomes ->  ->  ->  ->  ->  ->  ->  ->  -> keepvarlsts -> keepvars	 				 *
	   *	   							gotSMvars -^           cweight & indicator & prefix -^   ifvar&keepwtv -^  		 			 *
	   *	  														optadd & optad1 ^	     contextvars ^				 			 *
	   *																															 *
	   *  [SCHEMATIC OF ROUTE (approxmtly ordred by position in wrapper) TO IDENTIFYING VARS THAT NEED TO BE KEPT IN WORKING DATA]	 *
	   *																															 *
	   *******************************************************************************************************************************																	
		
		
				  

	
*	**************************										********************************************************************
*	if "`cmd'"!="genstacks"  {										// FOR GENSTACKS, FOLLOWING CODEBLKS ARE SUBSTITUTED IN 'genstacks0'
*	**************************										********************************************************************
																	// NOT IN V10
																	
		global SMwarned = 0											// Flag stops `prfxvars' warning from being duped in wrapper(2.1)																	
			
																	// IN 0.2 OPTNS FROM LAST VARLIST WERE DISTRIBUTED EARLIER, AS NEEDED 
*		*****************************
		while "`varwtoptlst'" !=""  {								// Repeat while anothr pipe-delimited varlst remains in 'varwtoptlst'
*		*****************************								// (so rest of codeblk is collecting lists of items, 1 per varlist)							
																	// Here parse the stackMe varlist, may still have following format:
																	// [[string_]inputvar(s):] outcomevars [ifin][weight] [no opts here]
																	// (strictly, all vars are inputs; some yield str-prefxed outcomes)
																	// (ABOVE 3 LINES REFER TO v9 'stackMe'; NEEDS TESTING FOR v10)

		   local nvl = `nvl' + 1									// `nvl' from top of codeblk 2, counts n of varlists in cmd

		   gettoken anything varwtoptlst : varwtoptlst, parse("||")	// Put successve `varwtoptlst's (delimitd by "||") into 'anything'
																	// (`anything' should repeat the varlist parsed seen in 0.3)
		   if "`varwtoptlst'"==""  local lastvarlst = 1				// If more pipes don't follow this 'varlist', reset 'lastvarlst'=1 
		   
		   else  {
		   	 local varwtoptlst=strtrim(substr("`varwtoptlst'",3,.)) // Else remove those pipes from what is now the head of 'varwtoptlst'
		   }														// (and trim off any following blanks)		
		   
		   gettoken vars opts : anything, parse(",")				// At this point there are genrally `opts' either user-optiioned or
																	//  repurposed from what should be the final `varwtopts' in 0.2
		   local anyopts = 1
		   if "`opts'"=="" local anyopts = 0						// Flag for use when resetting option list on varlists after the 1st
		   
		   local optlist : char _dta[OPTLIST`nvl']					// Retrieve the culled & expanded list of user-opted 'optname+arg's
																	// (defined as a _dta characteristic just before wrapper(0.4))
*		   *********************
		   local 0 = "`optlist'"									// This is from 'varlist [if][in][weight], optns' typed by the user
*		   *********************																	// (placed in local `0' because that is what 'syntax' cmd expects)
																	// (so will need to restore it (up to [ifinwt]) after processing)
		   local saveanything = "`anything'"
		   
		   local mask : char _dta[MASK`nvl']						// This is the summary mask containing only optioned syntax elements
local show="`mask'"		   
		   ***************											// CODE ALSO OCCURS IN CODEBLK 0.1, IN VERSION 10
		   syntax [anything] [if][in][fw iw aw pw/], [`mask' *] 	// (trailing "/" ensures that weight 'exp' does not start with "=")
*	       ***************											// Syntax command finds in `anything' following 'ifinwt' & options
																	
	

																	// ****************************************************************
*		   *************											// HERE DEAL WITH [ifin] or [weight] expressns appending 1st varlst
		   if `nvl'==1  {											// ****************************************************************
		   *************											// If this is the first varlist

			  local endv = ""										// By default assume no "if","in" or "weight" following the varlist
			  
			  local ifin = "`if' `in'"								// Ensure 'if' and 'in' expressions occur only on first varlist
																	// (or on final varlist treated as first in codeblk 0.2 above)
		
			  if "`if'" != ""  {									// If not empty, calls for `if' when establishing a working dataset
				 local endv = "if"
				 tempvar ifvar										// Create a temporary variable to indicate which obs will be kept
				 gen `ifvar' = 0									// Don't know name(s) of vars in 'if' expression but can substitute 
				 qui replace `ifvar' = 1 `if'						//  this indicator whose name is known
				 local ifexp = "if `ifvar'"							// Local will be empty if none. 
			  } //endif `if'										// THINK ABOUT TREATING IFVAR AS A ./1 VARIABLE FOR EACH VARLIST	***
		
			  if "`in'"!=""  {										// If not empty, calls for `in' when establishng the working dataset
				 if "`endv'"=="" local endv = "in"
				 local inexp = "`in'" 								// Store in inexp
			  } //endif `in'										// If "'inexp`nvl'"!="" code "`inexp`nvl'" in codeblock 6 below

																	// Weight expressions will be evaluated varlist by varlist
		   } //endif 'nvl'==1										// What follows applies to ALL varlists
		   
		   if "`endv'"=="" & "`weight'"!=""  local endv = "["		// If no [ifin] still may be `weight' to demark the end of varlist
																	// (so "[" at start of weight would be that demarcator)
*		   *********************************************************	
		   if "`endv'"!=""  gettoken anything rest : anything, parse("`endv'")
*		   ********************************************************	// 'rest' now has any 'ifin' or [wt]; anythng has neithr
																	// Else no need to strip anything from end of varlist
																	// (we will restore this varlist after we finish weight processng)
																	// (just before "next while", preceeding codeblk 3 below)

*		   *****************										**********************************							
		   if `nvl'>1  {											// IF THIS IS 2ND VARLIST OR LATER
*		   *****************										**********************************
		  		   
		      local ifin = "`if' `in'"
		   	  if "`ifin'"!=""  {
		   		  errexit "Only 'weight' expressions allowed on varlists beyond the first, not 'if' or 'in'"
*               		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  exit 1											// 'exit' command takes us back to caller, skipping rest of wrappr
																	// VARLISTS BEYOND THE FIRST MAY ALSO HAVE JUST ONE OPTION, PROCESSD
			  } //endif												// FOR CONVENIENCE IN CDEBLK 0.2 ABOVE (WILL BE OVERRIDDE BY PRFXSTR
																	//  IF ANY, STILL PROCESSED IN THIS CODEBLK, THOUGH NOT DOCUMENTED)
																	// BUT OTHER OPTIONS WILL CARRY OVER (THIS SHOULD BE DOCUMENTED)	***																	
		   } //endif `nvl'>1										// 'anything' now contains just varlists or a stublist		   
		   
		   
		   
		   
*		   ******************************************************************
*		   Remaining code in this block is for all varlists, 1st & subsequent
*		   *****************************************************************
		   
																	//******************************************************************
		   if "``opt1''"!=""  {										// HERE HANDLE USER-OPTD VARS & OTHER STRNGS VARYING across varlists
																	//******************************************************************
																	
			  if "`prfxtyp'"=="var"  {								// If an additional var, varlist, stub or string was optioned
				 local prfxvars = "`opt1"							// DOUBLE-QUOTES NO LONGR NEEDED TO ACCESS user-optd VAR(S)/STRING(S)
			  }														// (made more directly accessible towards end of codeblk 1.1, above)
			  		
			  else  {												// Else `prfxtyp' must flag dummy variable stubname(s) or a `prfxvar'(list)
				 if "`cmd'"=="gendummies"  local stub = "`opt1'"	//
				 if "`cmd'"!="gendummies"  local prfxvar = "`opt1'"
			  }														// Direct the optioned name(s) according to `cmd'
				 
		   } //endif ``opt1''
		   
		   if "`weight'"!=""  {										// If a weight expression was appended to the current varlist
																	// (the trailing "/" in the weight syntax eliminates redundnt blank)
			  local wtexp = subinstr("[`weight'=`exp']"," ","$",.)	// Substitute $ for space throughout weight expression
																	// (ensures one word per weight expression)
																	// (has to be reversed for each varlist processed in 'cmd'P)
																	
		 	  ***************										
			  getwtvars `wtexp'										// Invoke subprogram 'getwtvars' below, maybe calling errexit
			  if "$SMreport"!=""  exit 1							// Skip rest of wrapper, includng 'skipcapture', thru' break exit
*		 	  ***************										// $SMreport is empty if getwtvars did not call 'errexit'
	   
			  local wtvars = r(wtvars)								// (seemingly returned by 'getwtvars'; reformulates `wtexp'?)
			  if "`wtvars'"=="."  local wtvars = ""					// SEEMINGLY r(wtvars) RETURNS "." WHEN wtvars IS EMPTY				***
			  local keepwtv = "`keepwtv' " + "`wtvars'"				// Append to keepwtv the 1 or 2 vars extracted by prog 'getwtvars'
																	// (use double-quotes to access the var(s) pointed to by `wtvars')
																	// (`keepwtv' morphs into keepifwt & is kept at end of codeblk 2.1)
			  global noweight = ""									// Turn off $noweight' flag; calls for full tracking across varlsts
																	// (should match what 'syntax' WOULD have delivered if no prefixes)
																	
			  while wordcount("`wtexplst'")<`nvl'-1  {				// While 'wtexplst' is missing any previous weight expressions..
				local wtexplst = "`wtexplst' null"					//  pad 'wtexplst' with "null" strings for each missing word
			  }														// Padding ends with previous 'nvl'
			  local wtexplst = "`wtexplst' `wtexp'"					// Append current weight expressions to list for passing to `cmd'P
																	'
		   } //endif 'weight'										// Weight expressions elaborated below & at end of codeblk (6.2)
		
		   else  {													// Else there was no weight expression appended to this varlst

			 if "$noweight"==""  {									// If there was a previous `wtexp' (so this is not first 'nvl')
			   while wordcount("`wtexplst'")<`nvl'  {				// While previous 'wtexp' expression was missing
				 local wtexplst = "`wtexplst' null"					//  pad the `wtexplst' with null strings for each missing word
			   }													// (ensurs empty 'wtexplst' stays empty when passed to 'cmd'P in 7)

			 } //endif $noweight
			 
		   } //endelse	
		   
		   local llen : list sizeof wtexplst
	  
		   while `llen'>0  & `llen'<`nvl'  {						// Finish up this varlist's contribution to wtexplst
			 local wtexplst = "`wtexplst' null"						// Pad any terminal missing 'wtexplst's (must be after 'endwhile')
			 local llen : list sizeof wtexplst
		   }		  												// More on wts at end of (2.1); they are tested in codeblock (6.2)
		   
*		   ***************************************		  			// (CONCEPTUALLY, THIS PADDING OF 'wtexplst' BELONGS WITH GLOBALS
		   global wtexplst`nvl' = "`wtexplst'"						//   VARLISTS`nvarlst', ETC., FILLED AT END CODEBLK(2.1); dealt
*		   ***************************************					// 	 with here 'cos there is one per varlist)
			
	

local show = "`opt' -> ``opt''"
					

global errloc "wrapper(2.1)"
pause(2.1)

		  if "`cmd'"!="genstacks"  {								// 'genstacks' does its own varlist processing
				
				
										// *********************************************************************************************
										// (2.1) Here check the validity of names split into 'inputs' `prfxvars' and 'prfxstrs' for each 
										//		 varlist. All outcome variables will get names based on input varnames (except with gen-
										//		 dummies if stub-names are optioned. VERSION 10 NO LONGER USES PREFIXVARS BUT THESE ARE
										//		 STILL PROCESSED BY THIS CODEBLOCK IN CASE WE DOCUMENT THAT AS AN ALTERNATIVE SYNTAX.
										//		 Such 'prefixvars' are vars that generally provide additional data needed to generate 
										//		 desired outcomes (the exception is genyhats, where a prfxvar can provide an outcome var-
										//		 name). As well as supplementary variables, a (list of) prefixvars can itself be prefxed 
										//		 by a string that replaces, for the current varlist, any user-defined 'aprefix' optiond
										//		 for the cmd as a whole (useful when there was only one full optionlist allowed for the
										//		 set of varlists that could accompany a command). So when parsng a varlist we looked for 
										//		 outcomes, input var(s) and an input string (we still ensure all vars are unabbreviated 
										//		 and that hyphenated varlists are expanded). NOTE that several outcome vars are often 
										//		 produced (distinguished by different prefix-strings) that share the same input varname. 
										//		    All this complexity should not trouble the average stackMe user, preparing a single-
										//		 survey dataset for a single country (perhaps even a time-series cross-section dataset 
										//		 with multiple surveys from the same country) who can use the standard Stata command
										//		 format << varlist [ifinwt], options>>, with a single varlist per command. The few users
										//		 who are pre-processing multiple time-series cross-section datasets will hopefully be 
										//		 motivated to use the alternative syntax that permits the processing of several varlists
										//		 on each single pass through these enormous datafiles.
										//		    The complexity does call for patience when trying to make sense of program logic.
										//		 IN THIS CODEBLK WE LOOK FOR PREFIX-VARS AND PREFIX-STRINGS NOT EXPECTED IN VERSION 10.										//		 ***************************************************************************************
										// *********************************************************************************************
										

			 local multivariate = "$multivariate"				// By default employ user-optioned version of this flag
				
				
		     gettoken precolon postcolon : anything, parse(":")	// Parse components of 'anything' based on presence of ":", if any,
			 
																// ******************************************************************
																// FOLLOWNG RELATES TO EARLIER VERSIONS USING VARLIST PREFIX OPTIONS)
																// `precolon' holds a var(list) whose first (or only) varname may be 
																// prefixd by as many string-prefixes as there are prefixvars. The 1st 
																// is the interim prefix that will be attached to outcome variables by 
																// 'cmd'P and elaborated by 'cleanup'. The 2nd is the workflow record 
																// created by 'cleanup', one charcter per previously excutd stackMe cmd 
																// (except for 'genmeanstats' whose outcomes are not includd). In this 
																// codeblk we need to be aware that any varname typed by the user may 
																// already have up to two `prfxstr's, separated and terminated by under-
																// line charactrs. In this codeblck a third prefix string may be usr-
																// defined. If so the two originally existng prefix stringes will be 
																// concatnate by 'cleanup' so that no variable name is ever preceeded 
																// by more than two such strngs. Here we just need to take account of 
																// the parsing problem created by varnames that may have one, two, or
																// no such prefix strings. (Actually only the fact that there may be
																// more than one such string need concern us; the rest can be treated
																// as part of the first variable's name. Happily, any user-supplied 
																// prefix string will be followed by "@", not "_".)
																//   THIS COMPLEXITY LED TO ABANDONMENT OF PREFIX STRINGS IN v10.
																// ********************************************************************
	
			 if "`postcolon'"!=""  {							// If 'postcolon' is empty then there's no colon (SO NOT EXECUTD IN v10)
																// (so, in v10, `vars' retains the content gained above, in wrapper (2))
			   local `opt1' = "`savedpt1'"						// CLUGE RESTORES ``opt1'' SAVED EARLIER FROM OVERWRITINE				***
			   if "`prfxtyp'"=="var" local prfxvar = "``opt1''" // If no colon, treat `opt1' as varnames (will be empty unless user-optd)
			   else  {											// Else treat `opt1' as stubname or string-prefix
			   	  local strprfx = "`opt1'"						// And save in `strprfx'
			   }
			 } //endif
																// (FOR ACCOUNT OF PURPOSE & WORKING OF 'checkvars' SEE END OF CODEBLK 0.3)
*			 ************************							// Here we pre-process hyphenated and abbreviated un-prefxed varlist
			 checkvars "`vars'"									// `vars' yield all inputs that become outcomes
			 if "$SMreport"!=""  exit 1							// Exit if 'checkvars' reported an error
*			 ************************							// See first call on 'checkvars', in wrapper(1.1) above. for details
			 local vars = r(checked)							// (get vars from r(checked), not 'anything', whch may have hyphens)
			 
			 
		     if "`postcolon'"!=""  {							// If there is a colon (only before v10)
									
			   gettoken preat gotat : precolon, parse("@")		// If parse char is "@" then we have a @-delimited string prefix
			   if "`gotat'"!=""  {								// If `gotat' is not empty..
			   	 local strprfx = "`preat'"						// Store the pre-"@" string in `strprfx'
				 local prfxvar = strtrim(substr("`gotat'",2,.))	// Store the post-"_" portion of `gotat' in `prfxvar' (may be plural)
			   }
			   
			   else  local prfxvar = "`precolon'"				// (`prfxvar' may be plural if the var is actually a varlist)

*			   **********************					*******	// Here we pre-process any `prfxvar'(s)
			   if "`prfxvar'"!="" & "`prfxtyp'"=="var"  local checkvars "`prfxvar'"				
			   if "$SMreport"!="" exit 1				//*************	// Exit if 'checkvars' invoked 'errexit'
*			   **********************							// (ACCOUNT OF PURPOSE & WORKING OF 'checkvars' AT END OF CODEBLK 0.3)
			   if "`prfxvar'"!="" & "`prfxtyp'"=="var"  local prfxvar = r(checked)
																// (confusingly, `prfxvar' is singular even tho' there may be more)
																
			 } //endif `postcolon'
				   
			 if "`cmd'"=="gendummies" | ("`versn'"=="10"&"`opt1'"!="")  { // For versn 10, `opt1' yields default for othr `cmd's too	***
				local stub = "``opt1''"							// By default gendummies' stubnames are user-optioned					***
				if "`cmd'"!="gendummies" {						// (just to be safe, don't make this 2nd change for 'gendummies')
					local prfxvar = "``opt1''" 
					if "``opt1''"!=""  local pfrxvar = "``opt1''" // If `opt1' points to the vars/strs that were user-optioned..
				}												// Then  put those varnames or string-names into `prfxvar'
				if "`strprfx'"!=""  {							// (ABOVE CLUGE SHOULD ACCMODATE BOTH VERSIONS 9, OR EARLIER, AND V 10)
				   local stub = "`strprfx'"						// But if there are `strprfx's they would override any optd stubnames
				   local strprfx = ""							// Need to empty `strprfx' since these do not have the same function
				}
				if "`cmd'"=="gendummies"  {
				  local nvars = wordcount("`vars'")				// Find length of outcome varlist
				  local nstubs = wordcount("`stub'")			// (gendummies may have multiple stubnames)
				  if  `nstubs' & `nvars'!=`nstubs'  {			// If there are any stubs, ensure as many stubnames as variables
				    errexit "'gendummies' varlists must have as many stubnames as varnames"
					exit 1										// (not mentioned is that a single stub can have a strprfx)
				  } //endif `nvars'!=`nstubs'						// Exit to caller after error is reported by errexit
				} //endif `cmd'
			 } //endif `cmd'==`gendummies' | ("`versn'"=="10.."								
			 
			 local input = "`vars'"								// By default, inputs provide the root for each outcome varname

			 if "`strprfx'"!="" & !$SMwarned {					// (this error can occur for any command that has an opt1 var(list))
			 
				noisily display _newline "NOTE: Prefix to varname overrides, for that varname, any `opt1' option{txt}"
*               						  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				global SMwarned = 1								// 'opt1' is the first option in every stackMe cmd's option list
			 													// (it is the option that will be replaced by any 'prfxvars')
		     } //endif
			   
			 if "`input'"!=""  local inputs = "`inputs' `input'"	  // Cumulate the inputs that ultimately become prefixed outcomes 
			 if "`prfxvar'"!="" local prfxvars="`prfxvars' `prfxvar'" // Cumulate list of prfxvars over varlists
																	  // ABOVE PLURAL LOCALS ARE ACCSSD IN WRAPPR

local show = "`opt1' -> ``opt1''"
																// GLOBALS DON'T RETAIN CONTENTS THRU prserve/'restore'/`merge' CYCLES
*			*************************************************	// Here is the first step in accellerating all 'cmd'P programs
			char define _dta[NVARLISTS] `nvl'					// Puts in data char the # of current varlist; ultimately n of varlists
			char define _dta[VARLISTS`nvl'] "`input'"			// Store in charactrstic where can be found in 'cmd'P and elsewhere
			char define _dta[PRFXVARS`nvl'] "`prfxvar'"			// Store in charctrstc name(s) found in var(list) that preceed a colon
			if "`prfxvar'"=="`opt1'" & "``opt1''"!=""  char define _dta[PRFXVARS`nvl'] "``opt1''"
			char define _dta[PRFXSTRS`nvl'] "`strprfx'"			// String may prefix a prfxvar(list) – only one per prfxvar(list) 
			if "`stub'"!="" char define _dta[VARSTUBS`nvl'] "`stub'" // (list of) stub(s) matchng N of vars in currnt varlst (only gendu)
			char define _dta[MULTIVARIATE`nvl'] "`multivariate'" // Successive genyh varlists may invoke multivariate analysis or not
			char define _dta[LIMITDIAG] "`limitdiag'"			// For use when user-optioned `limitdiag' is not accessible
*			*************************************************	// DISTINGUISH ABOVE FROM SOME THAT LOOK THE SAME W'OUT TRAILING `nvl'
																// PARALLEL GLOBAL wtexplst`nvl' WAS FILLED IN CODEBLOCK (2)

*																// *****************************************************************
																// NOTE THAT A STRING PREFIXING A VARNAME IS NOT PREFIXING A PRFXVAR
																// SO THE VARNAME IS SIMPLY EXTENDED BY THAT PREFIX. IT PROBABLY
																// BECAME PART OF THE VARNAME AS A RESULT OF A PREVIOUS STACKME CMD
																// ****************************************************************
																	
			local outcome = ""									// This string needs to be emptied for next varlist
			local input = ""									// Ditto
			local vars = ""										// Ditto
			local prfxvar = ""									// Ditto
			local strprfx = ""									// And ditto
							
		    if `lastvarlst'  continue, break					// If this was identified as the final list of vars or stubs,						
																// ('break' ensures next line to execute follows '' } //next while '' )	
			
*		    *********************************************			
		    local multivarlst = "`multivarlst' `vars' ||"		// Here multivarlst is constructed without 'ifin' or options
*		    *********************************************		// (any such were removed by Stata's syntax command; just weights
																	
*			***************************************
			foreach optname  of  local optnmlist  {				// BLANK OUT ANY OPTNAME THAT MIGHT NOT BE REPLACED BY NEXT OPTLIST
			local `optname' = ""								// (we use same optnmlist as for the '' while `cmd' '' loop, earlier)
			} //***********************************
			
			
			
		  } //endif `cmd'!="genstacks"							// End of code that genstacks will process for itself
			
			
*	   	****************										********************************************************************
		} //next '' while `varwtoptlsts' ''						// End of codeblks processing successive varlists within multivarlst
*	    ****************										// Local lists processed below cover all varlists in multivarlst	
*																********************************************************************

	
		if substr("`multivarlst'",-2,2)=="||" {					// See if last varlist ends with "||" (user might have done this)
		   local multivarlst = strtrim(substr("`multivarlst'",1,strlen("`multivarlst'")-3)) 
		}														// Strip those pipes if so
	
	    local llen : list sizeof wtexplst						// Finish up the wtexplst now that all varlists have been processed	
	    while `llen'<`nvl'  {									// For weight expressions before the final one..
		   local wtexplst = "`wtexplst' null"					// Pad any terminal missing 'wtexplst's (must be after 'next while')
		   local llen : list sizeof wtexplst
	    }
	
	
	
*	    ************************************
	    local keepifwt = "`ifvar' `keepwtv'"					// Must be appended after exiting 'while' loop `cos only done once 
*	    ************************************					// (list of vars/stubs providing names of vars generated by 'cmd'
																//  per varlst WAS encoded in $wtexplst' in (2), updated just above)
																// (kept at end of this codeblk)
																
																
*	 ********************										***********************************************************																	
*	} //endif ! genstacks										// End of codeblocks executed for all cmds except genstacks	
*	 ********************										// (opened at start of codeblk 0.2)
																***********************************************************


	
	
	
	
	

global errloc "wrapper(3)"	
pause(3)


										// *******************************************************************************************
										// (3) Check a couple more options, omitted above, for correct syntax; add to local `keepvars'
										//	   the various variables encountered above that need to be kept in the working dataset.
										// *******************************************************************************************
										
	
	if "`limitdiag'"=="" {										// If `limitdiag' was not optioned
	   local limitdiag = -1										// In case `limitdiag' was not optioned, assign its default value
	   local xtra = 0
	}
	if `limitdiag'==-1  local limitdiag = .						// By default make `limitdiag' a very large number (==.)
	char define _dta[LIMITDIAG] "`limitdiag'"					// (first point at which this global can be set by all commands)
																// THIS IS SEEMINGLY DONE TWICE
																
	global multivarlst = "`multivarlst'"						// Some legacy code still uses the global
	char define _dta[MULTIVARLST] "`multivarlst'"				// Make it accessible to caller programs and subprograms


	if "`cmd'"!="genstacks"  {									// `cmd' 'genstacks' will again skip this codeblk
																// ('genst' skipped the code establishing following charactrstcs)
	
*	  ******************
	  checkSM "`inputs'"										// Establish whether SMvars are referenced in user's varlist
	  if "$SMreport"!=""  exit 1								// Short-cut skips remainder of wrapper including 'skipcapture'
*	  *******************										// (if 'errexit' was called from 'checkSM')

	  local gotSMvars = r(gotSMvars)							// 'gotSMvars' is list of any SMvars in the active data
	  local gotSMvars = subinstr("`gotSMvars'",".","",.) 		// Remove any missing variable symbols (should not be any)
																// WE DEAL WITH THESE IN CODEBLK (5)
																// ********************************************************
*	  *********************************							// Update 'keepvars' with additions from this codeblock
	  local keeplist = "`keepoptvars' `keepifwt' `inputs' `prfxvars' `gotSMvars'"	// Vars identified for working data now in keeplist
	  local keepvars = strtrim(stritrim(subinstr("`keeplist'",".","",.)))	// Eliminate any "." in 'keepvarlsts' (seemingly from unab)
	  local keepvars : list uniq keepvars						// Only retain one exemplar of each var in workng dta
*	  *********************************							// ********************************************************

	  local nvarlsts : char _dta[NVARLISTS]

*	  local nvarlsts = `nvarlst'									// This local registers the final varlist processed above
	  forvalues nvl = 1/`nvarlsts'  {								// Cycle thru successive varlists
	
	    local prfxvars : char _dta[PRFXVARS`nvl']				// We retrieve these from characteristics `cos we fear loss of globals
	    local stubs : char _dta[VARSTUBS`nvl']					// Same concerns for both `prfxvars' and `stubs'
	    
		local names = "`prfxvars'"								// NEEDED FOR CHECK BELOW THAT SHOULD HAVE BEEN CONDUCTED EARLIER		***
	    if "`cmd'"=="gendummies"  local names = "`stubs'"	
		
	    if "`names'"!=""  {										// If varlist includes prefixvars
		
	   	  if strpos("gendummies geniimpute genplace","`cmd'")==0 { // If `cmd' is not one of those listed ..
			 if wordcount("`names'")>1  {						// (genyhats can only have one)
			   	errexit "Command `cmd' cannot have multiple prefix-vars"
			    exit 1											// Exit takes us straight to caller, skipping rest of wrapper
			 } //endif wordcount
			 
		   } //endif `cmd'
	    } //endif 'prfxvars'
	   
	    else  {													// Else there is no prefixvar 
	   	  if "`cmd'"=="genyhats" & "`depvarname'"=="" { 		// genyhats requires an optioned depvarname if no prefixvar
		     local multivariate : char _dta[MULTIVARIATE`nvl']
*			 if "`multivariate'"!=""  {
				errexit "For genyhats a depvarname must be optioned" /*" with no prefixvar" */ //removed for versn 10
*               	  	 123456789012345678901234567890123456789012345678901234567
				exit 1
			 }	
/*																// COMMENTED OUT FOR VERSION 10
			 else {
			 	errexit "For bivariate yhat analyses (default) a depvarname must be optioned" 
			 }
			 exit 1
		  } //endelse `cmd'=="genyhats"							// PREVIOUS COMPLEX GENYHATS COMMANDLINE IS REASON FOR VERSION 10
*/
	    } //endelse
	   
	  } //next 'nvl'

	
	  if "`cmd'"=="genplace" & "`indicator'"!=""  {				// `genplace' is the only cmd with additional var-naming optn 			***
																// (beyond the 'opt1' option handled above) so handle it here
	    gettoken ifwrd rest : indicator							// See if "if" keyword is first word in 'indicator'
	    if "`ifwrd'"=="if"  {									// If "`indicator'" string starts with "if"
		  if "`rest'"=="" {
			 errexit "Missing 'if' expression"
			 exit 1
		  }
		  tempvar indicator										// If indicator is created with 'ifind', make it a tempvar
		  qui generate `indicator' = 0							// So generate a new var named 'indicator', 0 by default
		  qui replace `indicator' = 1 if `rest'					// Replace values of that variable to accord with 'ifind' expression
	    }														// ('ifind' may include varname(s) but don't need to keep those)
	    else unab indicator : `indicator'						// Else 'indicator' contains a varname; unabbreviate it
																// ('unab' will exit with appropriate error msg if no such var)
	  } //endif 'cmd'=='genplace'								// ('indicator' local now names either original or tempvar variable)
	
																// **************************************************************
	  local keepvars =strtrim(stritrim("`keepvars' `indicator'")) // Update 'keepvars' with additions from this codeblock
																// ***************************************************************

																
																
	} //endif `cmd'!="genstacks"
	
	
	noisily display ".." _continue
	global busydots = "yes"										// Flag indicates previous display ended with _continue

	
	
	
	

global errloc "wrapper(3.1)"	
pause(3.1)
										// ********************************************************************************************
										// (3.1) Check additional options specific to certain commands for correct syntax; add to local
										//	   `keepvars' a list any 'opt1' (and 'opt2 for genplace) – the first variable(s) in any 
										//		optionlist) – if those option(s) name variable(s).
										// ********************************************************************************************
	
							
						
	
	if "`cmd'"=="genmeanstats"  {							// 'genmeanstats' makes unique use of two-character outcome var prefixes
															// (user-selected by employing its 'stats' option)
		global statprfx = ""								// Three globals share this linkage with relevant subprograms
		global statrtrn = ""								//
		global statpos = ""									// Initialize global as head of list that will accumulate all `statpos's

*		*********************
		local 0 = ", `stats'"								// Local 0 is where `syntax' command expects to find user's command line
*		*********************

*		**************************************************	// ('stats' is name of option in which user placed desired stats)
		syntax , [ N MEAn SD MIN MAX SKEwness KURtosis SUM SWEights MEDian MODe _all ] // List is also in 's0', differently formatted
*		**************************************************
															// Command 'syntax' selects those actually optioned, in 's1' below
		local s0 =     lower("N MEAn SD MIN MAX SKEwness KURtosis SUM SWEights MEDian MODe") // List of stats (r-names) in lower case
		local s1 = strtrim(stritrim("`n' `mean' `sd' `min' `max' `skewness' `kurtosis' `sum' `sweights' `median' `mode'")) // optd stats
		local s2 = strtrim(stritrim( "n   me     sd   mi    ma    sk         ku         su    sw         md       mo"   )) // Prfx inits
															// Actual return names: "N" for "n"; "sum_w" for "sweights"	
		if "`_all'"!="" {									// if "_all" was optioned
		
		   if wordcount("`s1'")>0 {							// if any other stats were optioned
			  errexit "Cannot option any other stats along with '_all'"
			  exit 1										// Invoke errexit
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
		}													// (globals to be accessd in  'genstatsP' & 'cleanup' for pfxng and labelng)

		scalar STATRTRN = "$statrtrn"						// As with VARLSTS etc. these globals are not retaining their contents
		scalar STATPRFX = "$statprfx"						// (perhaps because they get emptied over series of preserve/restore cycles)
		char define _dta[STATRTRN] "$statrtrn"				// Backups in case scalars are lost
		char define _dta[STATPRFX] "$statprfx"

		
	} //endif `genmeanstats'
		
	

	
	
	
	
global errloc "wrapper(4)"
pause(4)
										// ***************************************************************************************
										// (4) Save 'origdta'. This is the point beyond which any additional variables, apart from
										//	   outcome variables generated by stackMe commands, will not be included in the full 
										//	   dataset after exit from the command or after restoration of the data following an 
										//     error. Here initialize ID variables needed for stacking and to merge working data 
										//	   back into original data. Ensure all vars to be kept actually exist, check for any 
										//	   accidental duplication of existing vars. Here we deal with all kept vars, from 
										//	   whatever varlist in the multivarlst set (except SMvars, added below if needed)
										// ***************************************************************************************
										

	capture drop SMorigunit									// ***************************************************************
	generate long SMorigunit = _n 							// Variable inserted into every stackMe dataset (enables merge of 
	local keepvars = "`keepvars' SMorigunit"				//  working data back into original dataset); add it to `keepvars'
															// ***************************************************************
															
*	************											// *******************************************************************
	tempfile origdta						    			// Will be merged with processed data after last call on `cmd'P
	quietly save `origdta', replace							// (, replace option in case file remained extant on prior error exit)
	global origdta = "`origdta'"							// Put it in a global so as to be accessible from anywhere
*	************											// (this temporary file will be erased on exit)	
															// (SMorigdta will be restored before exit in event of error exit)
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
pause(5)

										// ******************************************************************************************
										// (5) Deal with possibility that prefixed outcome variables already exist, or will exist
										//	   when default prefixes are changed, per user option. This calls for two lists of
										//	   global variables: one with default prefix strings and one with prefix strings revised 
										//	   in light of user options. Actual renaming in light of user optns happens in 'cleanup',
										//	   for each 'cmd', after processing by 'cmd'P; but users need to known before `cmd'P
										//	   is called whether there will be name conflicts. Meanwhile we must deal with any existing
										//	   names that may conflct with outcome names, perhaps only after renaming.
										// ******************************************************************************************
										
										
															
	if "`cmd'" != "genstacks"  {							// 'genstacks' command DOES NOW (v9+) prefix its outcome variables BUT
															// (LEGACY CODE DID NOT ANTICIPATE CHECKS THAT MAY ACTUALLY NOT BE NEEDED)	***
	   global exists = ""									// Empty list of vars w revised prefixes or otherwise exist as shouldnt	  

	   global prfxdvars = ""								// Global will hold the list of prefixed vars from subprogram 'isnewvar'.
	   global newprfxdvars = ""								// Ditto, for list of NOT already existing outcome vars 
	   global badvars = ""									// Ditto, for vars w "___" prefix, maybe due to previous error exit
				
															// See if simulated names of outcome vars already exist
*	   ********************									// (identify dups and conflicts, helped by user input)
	   local optionsP : char _dta[OPTLIST`nvl']				// Retrieve `optlist' from data characteristic saved earlier
	   getprfxdvars , `optionsP' `multivariate'				// BUT WE DONT DROP THEM UNTIL WORKING DATA ARE MERGED WITH origdta
	   if "$SMreport"!=""  exit 1							// (`multivariate' reflects `gotpfx' prefix, not affecting $multivariate)
*	   ********************									// 'optionsP' holds options needed to identify optioned prefix-strings
															// $SMreport is copy of `errmsg' (indicator that we need to exit)

	} //endif `cmd'!=`genstacks'
	

	
															// ******************************************************************
	if "$cmdSMvars"!=""  {									// (Global cmdSMvars filled by subprogram 'checkSM', invoked in 2.1)
															// HERE IS WHERE WE ADD COMMAND-SPECIFIC SMvars TO $exists SO USERS
															//  CAN DECIDE WHETHER TO DROP THEM
															// ******************************************************************
		foreach v  of  global cmdSMvars  {					// (cmdSMvars only exist for gendist geniimpute genstacks)		
		
			if "`cmd'"=="gendist" & strpos("SMdmisCount SMdmisPlugCount","`v'")>0  global exists = "$exists `v'"
			if "`cmd'"=="gendiimpute" & strpos("SMimisCount SMimisImpCount","`v'")>0  global exists = "$exists `v'"
			if "`cmd'"=="genstacks" & strpos("SMstkid S2stkid SMnstks S2nstks SMitem S2item SMunit S2unit","`v'")>0 ///
				global exists = "$exists `v'"				// $exists already holds any conflicted varnames found by 'getprfxdvars'
			if "`cmd'"=="genstacks" & "`dblystkd'"!="" & strpos("S2stkid S2nstks S2item S2unit","`v'")>0 ///
				global exists = "$exists `v'"				// For doubly-stacked data keep both SM.. & S2.. vars
															// (invoked in codeblock 5.0)
		} //next `v'
		
	} //endif $cmdSMvars
	
	
	
		

		
		
	
global errloc "wrapper(5.1)"
pause(5.1)


										//		 ****************************************************************************
										// (5.1) Call on '_mkcross' to enumerate all contexts identified by a single variable
										//		 that increases monotonically in increments of a single unit across contexts
										//		 (the final variable we need to include in the working dtaset)
										//		 ****************************************************************************
	
	  
	local nocntxt = 1										 
	if "$contextvars" != "" | "`stackid'" != ""  local nocntxt = 0  // Not nocntxt if either source yields multi-contxts
	local nocntxt = 0										// Flag indicates whether there are multiple contexts or not
	 
	if "`cmd'"=="gendummies"  local nocntxt = 1				// gendummies treats whole dataset as one context
															// WE ALREADY HAVE A FLAG FOR THIS, SET IN CALLER CODEBLK 0					***
	tempvar _ctx_temp										// Variable will hold constant 1 if there is only one context
	tempvar _temp_ctx										// Variable that _mkcross will fill with values 1 to N of cntxts
	capture label drop lname								// In case error in prev stackMe command left this trailing

	if `nocntxt'  {
		gen `_temp_ctx' = 1									// Don't need _mkcross to tell us no contextvars = just one contxt
	} 
	else {													// else we do have multiple contexts
	  
	    local cvars = ""
		local contextvars : char _dta[CONTEXTVARS]			// retrieve `contextvars' from temp char stored at end of codeblk 1.1
		if "`contextvars'"==""  local contextvars = "$contextvars"
	    foreach var  of  local contextvars  {
		   tempvar c`var'									// MARK CHANGED THESE INTO TEMPVARS IN CASE `errexit' LEAVES THEM EXTANT
		   clonevar `c`var'' = `var'
		   local cvars = "`cvars' `c`var''"
		}
		local cvars = "`cvars' `stackid'"                   // Append `stackid' as additional source of contexts
			
		global contextvars = "`contextvars'"				// Somewhere, contextvars are getting replaced by their values
		local ctxvars = "`cvars'"							// So we insulate the originals and use clones until we save the data
															// (when we will use the global to retrieve then)


*		****************
		quietly _mkcross `ctxvars', generate(`_temp_ctx') missing strok labelname(lname)										 	//	***
		if "$SMreport"!=""  exit 1							// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
*		****************									// 'SMreport' is only set by errexit, so this tells us there was an error
															// (generally calls for each stack within context - see above)
															// (enumerates only obs retained after 'ifexp' was executed in blk(4))


	} // endelse 'nocntxt'
			
	local ctxvar = `_temp_ctx'								// _mkcross produces sequential IDs for selected contexts
															// (NOT TO BE CONFUSED with `ctxvars' used as arg for _mkcross)
	quietly sum `_temp_ctx'
	local nc = r(max)										// This is the number of contexts (`c'), used below and in `cmd'P		
				

				


global errloc "wrapper(6)"													
pause(6)								//		 *****************************************************************************
										// (6)   Issue call on `cmd'O (for 'cmd'Open). In this version of stackmeWrapper the
										//		 call occurs only for commands listed; 'genyhats' will have opening codeblocks 
										//		 transferred to genyhtsO in a future release of stackMe. The programs called
										// 		 here are final sources of vars to be kept.
										// 		 Capture otherwise undiagnosed errors in programs called from wrapper
										//		 *****************************************************************************
										
										// *******************************************************************				 ***********
										// NOTE THAT IN THIS CODEBLK 'keepvars' TEMPORARILY MORPHS INTO 'keep' 	   (look for HERE MORPH)		
										// *******************************************************************				 ***********

										
*	gettoken precomma postcomma : multivarlst, parse(",") 	// CLUGE ADDRESSES PROBLEM DIAGNOSED BEFORE `cmd'P, BELOW					***
	local multivarlst = stritrim(subinstr("`multivarlst'", "," , "" , .)) // Replace all commas with null strings
															// APPEARS HERE `COS SAME PROBLEM AFFECTS CALLS ON `cmd'O
										
	if strpos("geniimpute genplace genstacks", "`cmd'") {	// If this is a cmd having a 'cmd'O call
															// Above 'cmd's each has a 'cmd'O program that accesses full dataset
															// (may add gendist & genyhats so only gendummies will be w'out 'cmd'O)
*	
*	 	******************** 
		`cmd'O `multivarlst', `optionsP' nc(`nc') nvar(`nvl') wtexp(`wtexplst') ctx(`_temp_ctx') orig(`SMorigdta') 
		if "$SMreport"!=""  exit 1							// ($SMrreport is empty if a non-zero return code was not reported)
*	 	********************								// Global SMorigdta IS included 'cos errors require it to be restored
															// (some 'cmd'O commands may still use legacy error reporting)

		local temp = ""										// *****************************************************************
															// For 'genstacks' `multivarlist' is actually a stublist from blk(6)
															// *****************************************************************

		if "`cmd'" == "genstacks"  {						// Command genstacks deals with own varlist/stublist
		
		   local temp = r(impliedVars)						// Returned from 'genstacksO' (other 'cmd's get 'multivarlst' in other ways)
		   if "`temp'"=="."  local temp = ""
		   if "`temp'"!=""  char define _dta[GENSTKVARS] "`temp'" // SEEMINGLY EMPTY `COS USING SCALAR
		   char define _dta[NVARLISTS] `nvarlst'			// 'genstacks' cmd will have skipped saving _dta char needed by 'getprfxvars'
*																													  ******************
		   local keep="`keepvars' `temp' `keepimpliedvars'"	// Append impliedvars to keepvars AND SAVE BOTH IN 'keep' HERE MORPH HAPPENS
		   local inputs = "`temp'"							//														  ******************
		   local multivarlst = r(reshapeStubs)				// Used in `cmd'P call, feeding 'reshapeStubs' to `cmd'P (misnamed as vars)
		   scalar GENSTKVARS = "`temp'"						// DK WHY THIS IS NOT COMING FROM 'genstO' – MAYBE DUE TO MISMATCHD PAREN?	***
		   char define _dta[GENSTKVARS] "`temp'"			// Feeds stublist to genstacks caller
		   local multivarlst = subinstr("`multivarlst'",".","",.)   // Remove any missing variable symbols
		   local multivarlst = subinstr("`multivarlst'",":"," ",.)  // Remove any colons
		   local multivarlst = subinstr("`multivarlst'","||"," ",.) // Remove any pipes
		   local multivarlst = strtrim(stritrim("`multivarlst'"))	// Remove any superfluous spaces
															// Remove all ":" & "||"; trim all leading, trailing & internal extra blanks
		   local dups : list dups multivarlst	
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
			  	 errexit "Lacking permission to drop duplicate varname(s)"
				 exit _rc
			  }
			  
			  drop `dups'									// If no errorexit, drop all dups
			  
		   } //endif 'dups'									// END OF CODEBLK COPIED FROM `getprfxdvars'
		   
		   local outcomes : char _dta[GENSTKVARS]			// NAME IS ANOMOLOUS SINCE GENSTACK OUTCOMES ARE VARS THAT WERE STUBS
														    // (but wrapper does not know that)
		} //endif 'cmd'=='genstacks'						// End of codeblock dedicated to 'genstacks'
		
		  
		else  {												// Else, for the other cmds currently having cmd'O programs
		
		  local temp = r(keepvars)							// Vars returned from `cmd'O when that cmd is not 'genstacks'
		  local temp = subinstr("`temp'",".","",.) 			// Remove any missing variable symbols							*******
		  local keep = "`keepvars' `temp'"					// Here morph from `temp' to 'keep'							   	OR HERE		
		  local minmax = r(minmax)							// Only relevant to 'geniimpute' for now					    *******
		  if "`minmax'"=="."  local minmax = ""
		  if `limitdiag'  local fast = "fast"				// Only relevant to geniimpute; limits per context diagnostics
		  
		}
					
			
	} //endif 'cmd'== genii', 'genpl' 'genst'				// End of clause determining whether 'cmd'O was called
															// ('cmd'O may itself have flagged an error)
															
	else  {													// Else command is not one with special requarements for call on 'cmd'P
															//																*******
		local keep = "`keepvars'"							//																OR HERE
	}														// 																*******
	
															// ********************************************************************
	if "`SMstkid'"!=""  local keep = "`keep' SMstkid"		// And add 'SMstkid', if extant, for diagnostic displays
															// ********************************************************************														
															// (Last bit of 'keep' before dropping all other vars from working data)
	

	
	if "`cmd'"!="genstacks"  {								// Get list of all outcomes for whatever command this may be
	
	  	local outcomes = ""									// (genstacks outcomes were already filled from r(impliedvars), above)
	  	local vars : char _dta[VARLISTS1]					// 'genstacks' has only one varlst (NOT REALLY SO, BUT TREATED THAT WAY)
	  	local outcomes = "`outcomes' `vars'"	
		
	} //endif
	
	
	  
	local lastvar = word("`outcomes'",-1)					// Record this so can we tell when the last var has been tested
		  
	tempvar count											// Check whether Stata missing data codes are in use
															
	if "`cmd'"!="genstacks"  {								// For now assume user will notice missing data stacks						***
		
	  foreach var  of  local keep  {						// If 'varsImplied..' was not invoked, `keep' has vars saved above

		quietly count if `var'>=.  							// Count any observations with values >= missing
		
		if r(N)<_N  continue, break							// Break out of loop with first Stata missing data code found
		
		if "`var'"=="`lastvar'"  {							// If this was the final variable in 'outcomes'..
		
			local msg = "No variable in the working dataset has any Stata missing data codes"
			display as error "`msg'." _newline 
			display as error "Use Stata's {help mvdecode} to transform sumeric missing values to Stata standard"
*					 	 	   12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			capture window stopbox rusure "`msg'; click 'cancel' and recode your missing data – or 'OK' to continue anyway"
			if _rc  {										// If user did not click 'OK'
				errexit, msg("Recode missing data") displ	// Display msg in results window as well as stopbox
				exit _rc
			}												// (we pass this point only if program did not exit)
		
			noisily display "Execution continues..."
			
		} //endif `var'
		
	  } //next var
			
	  capture drop `count'									// Drop this tempvar (if it still exists)

	} //endif !`genstacks'
	
	
	
*	****************************							// Check that all vars to be kept are actual vars
	if "`keep'"!="." & "`keep'"!=""  {						// If `keep' is neither missing nor empty..
		checkvars "`keep'"									// (FOR ACCOUNT OF PURPOSE & WORKING OF 'checkvars' SEE END OF CODEBLK 0.3)
		if "$SMreport"!="" exit 1							// Exit takes us straight back to caller, skipping rest of wrapper
		local keep = r(checked)								// (May include SMitem or S2item generated just above)
	} // ***********************							// (`keep' emerges from this 'if'-block not empty)
		
	else local keepvars = ""								// Else `keep' is, so far, empty; which ensures an empty `keepvars' 
		
	if "`keep'"!=""  {										// If we did not make `keepvars' empty then `keep' is not empty
		local keepvars : list uniq keep						// Stata-provided macro function to delete duplicate vars
		local keepvars = stritrim(subinstr("`keepvars'",".","",.)) // remove any missing variable indicators
	} 														
															
	global keepvars	= "`keepvars' `_temp_ctx'"				// ($keepvars' has all varlists and optioned vars with dups removed)
															// (put in global so can be accessed by 'cmd' caller and subprograms)
	
	
	
*	**************
*	**************											// ***************************************************************	
	keep $keepvars 											// HERE DROP UNWANTED VARIABLES FROM WORKING DATA FOR ALL CONTEXTS
*	**************											// ***************************************************************
*	**************



*										*************************************************************
										// NOTE THAT, JUST ABOVE, 'keep' MORPHED BACK INTO 'keepvars'
*										*************************************************************
	
	
	
					
global errloc "wrapper(6.1)"				
pause(6.1)								//		 ***********************************************************************************
										// (6.1) Cycle thru each context in turn 'keep'ing, first, the variables discovered above to
										//	     be needed in the working dataset and, later, the observations, selected by any 'if' 
										//	     or `in' expressions, before checking for context-specific errors.
										//		 ***********************************************************************************

	if `nc'==1  local multiCntxt = ""						// If only 1 context after ifin, make like this was intended			
															// (seemingly unused)														***
	if "`multiCntxt'"==""  local nc = 1						// If "`multiCntxt' is empty then there is only 1 context
															// (above convoluted logic ensures we get only 1 context either way)
	
	
	
*	********************									************************************
	forvalues c = 1/`nc'  {									// Cycle thru successive contexts (`c')
*	********************									************************************

																	  
	    scalar NOOBS = ""									// Scalar accoumulates NOOBS`nvl' results for each context														  
		char define _dta[NOOBS] ""
															// (provides list of varlists for which no observations was flagged)



	
		local lbl : label lname `c'							// Get label associated by _mkcross with context `c' ('cmd'P 
															// programs can optionally have labelname 'lname' hardwired)
		scalar LBL = "`lbl'"								// (use a scalar so does not get dropped at exit from program)
		char define _dta[LBL] "`lbl'"						

															
*		********										 	**************************************************************
		preserve  								 		 	// Next 3 codeblks use only working subset of context `c' data
*		********										 	**************************************************************


*		  ************												//  THIS COMMAND KEEPS ONLY WORKING DATA FOR THE CURRENT CONTEXT
		  quietly keep if `c'==`_temp_ctx' 							// `tempexp' starts either with 'if' or with 'ifexp &'
*		  ************									 			// ('ifexp' now executed after saving 'origdta' in blk 4)
				
   
*		  ******************************************		   		  
		  if `limitdiag'>=`c' & "$cmd"!="geniimpute" /*& "$cmd"!="genstacks"*/ {																					 
*		  ******************************************		  		// Limit diagnostics to `limitdiag'>=`c' and ! (geniimpute|genstacks)	
		
*			******************************
			showdiag1 `limitdiag' `c' `nc' `nvl'
			if "$SMreport"!="" exit 1								// ($SMrc is empty if a non-zero return code was not reported)
*			******************************							// Exit takes us straight back to caller, skipping rest of wrapper
			  
		  } //endif `limitdiag'>=`c' & ...
			 				 
							 
	
	
	
	
	  	
	
global errloc "wrapper(6.2)"		
pause(6.2)


										// (6.2) HERE ENSURE WEIGHT EXPRESSIONS GIVE VALID RESULTS IN EACH CONTEXT OF WORKING DATASET	***
								
								
								
		  if `limitdiag'>=`c'  {									// If we have not reached the user-set diagnostics limit
		  	
		    local noobs = ""

		    local lbl = LBL											// Get a local copy of scalar LBL
			
		    forvalues nvl = 1/`nvarlst'  {							// Cycle thru all varlists for this command		 
	   				 
		      if "`wtexplst"!=""  {									// Now see if weight expression is not empty in this context

			    local wtexpw = word("`wtexplst'",`nvl')				// Obtain local name from list to address Stata naming problem
				if "`wtexpw'"=="null"  local wtexpw = ""
				 
				if "`wtexpw'"!=""  {								// If 'wtexp' is not empty (don't non-existant weight)
				   local wtexp = subinstr("`wtexpw'","$"," ",.)		// Replace all "$" with " "
																	// (put there so 'words' in the 'wtexp' wouldn't contain spaces)
				 
*				   ***************************							  
			       capture qui sum SMorigunit `wtexp', meanonly		// Weight the only var known to exist in a call on 'summarize'
*				   ***************************						// (known because we created it)

			       if _rc  {										// A non-zero error code is likely be due to the 'weight' exprssion

				     if _rc==2000  local badwt = "`badwt' `lbl' `nvl'"	// Accumlate list of varlsts with no observations for this cntxt

				     else  {
					   local l = _rc
					   errexit "Stata reports program error `l' in context `lbl'" "`l'" // UPPER CASE lbl IS SCALAR; `l' IS RETURN CODE
					   exit 1											// Exit takes us straight back to caller, skipping rest of wrapper
				     }
																	
			       } //endif _rc

				} //endif `wtexpw'
				 
			  } //endif `wtexplst'
			 
		    } //next 'nvl'
		
		   
		    if "`badwt'"!="" {
			  errexit "Stata reports 'no obs' [weight] error in context `lbl' for varlist(s): `noobs' "
			  exit 1
		    }
		  
		  } //endif `limitdiag'

			
		   
	 	   

		   

global errloc "wrapper(7)"		
pause(7)



										//		*********************************************************************************
										// (7)  Issue call on `cmd'P with appropriate arguments; catch any `cmd'P errors; display 
										//		optioned context-specific diagnostics
										//		NOTE WE ARE STILL USING THE WORKING DATA FOR EACH IN TURN OF SPECIFIC CONTEXT `c'
										//		(IF NOT STILL SUBJECT TO AN EARLIER IF !$exit CONDITION)
										//		*********************************************************************************
	
	
// HERE `options'P WAS FOUND EMPTY ! WITH NO REFRENCE TO IT BEFORE THIS SPOT; BUT `multivarlst' HAD STANDARD OPTIONS WHERE NONE EXPCTD	***

// (CLUGE BEFORE `cmd'O, ABOVE, TRIES TO DEAL WITH 2ND OF THESE PROBLEMS, AS I CANNOT TRACK DOWN HOW THEY AROSE)
// (1ST PART IS ADDRESSED BY REMOVING `optionsP' FROM THE CALL ON `cmd'O AND HAVING THOSE OPTIONS RETRIEVED WITHIN THAT SUBPROGRAM)

/*
		  local optionsP : char _dta[OPTLIST1]						// Overrides varlst within calld program, but needed for legacy code
																	// (call transmits optlist for 1st varlist; `cmd'O not called later)
		  local optionsP = strtrim("`optionsP'")					// Strip off any leading or trailing blanks
		  
		  if substr("`optionsP'",-2,2)=="||"  local optionsP = substr("`optionsP'",1,strlen("`optionsP'")-2, . )
																	// Or trailing pipes
		  if substr(strtrim("`optionsP'"),1,1)==","  local optionsP = substr(strtrim("`optionsP'"),2,.)
																	// Or leading comma
		  if substr(strtrim("`optionsP'"),-1,1)==","  local optionsP = substr(strtrim("`optionsP'"),1,strlen("`optionsP'")-1)
																	// Or trailing comma
		  if substr("`optionsP'"),-1,1)==")"  local optionsP = substr("`optionsP'"1,strlen("`optionsP'")-1)
*/																	// Or trailing ")"
																	
																	// ABOVE COMMENTED OUT TO REDUCE DEPENDENCE ON SYNTAX COMMANDS		***	
																	// (so hard to debug!)
set tracedepth 5
		  
																	
*		  *******************				     	 				// Most `cmd'P programs must be aware of lname for ctxvars			***
		  `cmd'P `multivarlst' , nc(`nc') c(`c') nvarlst(`nvarlst') wtexplst(`wtexplst')
		  if "$SMreport"!="" exit 1									// ($SMreport is empty if a non-zero return code was not issued)
*		  *******************										// `nvarlst' counts the number of varlsts transmittd to `cmd'P
		  
		  
if `c'==`nc' {
  pause on
  pause exit `cmd'P
  pause off
}
																	// *****************************************************************
																	// IN VERSION 10 `multivarlst' & `optionsP' ARE RETRIVED FROM `cmd'P,
																	// ONE VARLIST AT A TIME, MAKING MUCH OF THIS CALL REDUNDANT. ONCE
		  local limitdiag : char _dta[LIMITDIAG]					// ALL `cmd'P ARE v10, REMOVE `multivarlst' & `optionsP' FROM CALL	***
																	// *****************************************************************
		  if `limitdiag'>=`c'  {
			
		    if NOOBS !=""  {										// If `cmd'P reports 'no observations' for one or more varlists..
																	// NOOBS APPEARS NOT TO BE ACCESSED BY `cmdP' PROGRAMS				***
			   local noobs = NOOBS									// Get local from scalar NOOBS for this context
			   local len = wordcount("`noobs'")
			   forvalues i = 1/`len'. {								// Cycle turn remaining words in `noobs'
				  local nvl = word("`noobs'",`i')
				  noisily display "No observatons in context LBL for varlist #`nvl'..."
*					 	 		   12345678901234567890123456789012345678901234567890123456789012345678901234567890 
				  if "`prfxtyp'"=="var"  {
*					 local vars = VARLISTS`nvl' + "``opt1''"		// Get relevant varlist from scalar, placed there before wrapper(3)				  	 
				  }													// COMMENTED OUT `COS DK WHY ADD ``opt1''; SHLD NOT BE IN `vars'	***
				  noisily summarize `vars'							// (and add ``opt1'')
			   } //next while										// STILL NEED TO STORE NOOBS`nvl' within each context for each cmd
		    } //endif NOOBS	
			
			
		    if "$cmd"!="geniimpute" {								// Limit diagnstics to commands other than 'geniimpute'		
																	// (geniimpute displays its own diagnostics)
		  	
*			  *************************************	
			  showdiag2 `limitdiag' `c' `nc' `xtra'					  
			  if "$SMreport"!="" exit 1							  	// ($SMreport is empty if an error was not yet reported)
*			  *************************************

		    } //endif
		   
		  } //endif $limitdiag
		  
		  else  {													// If limitdiag IS in effect, print busy-dots
		  
			 if `limitdiag'<`c'  {									// Only if `c'>= number of contexts set by 'limitdiag'
				if "`multiCntxt'"!= ""  {							// If there ARE multiple contexts (ie not gendummies)
					if `nc'<38  noi display ".." _continue			// (more if # of contexts is less)
					else  noisily display "." _continue				// Halve the N of busy-dots if would more than fill a line
				}
			 } //endif
				
		  } //endelse
			
		
		
	  
	  
	  	
		  local skipsave = 0										    // Will permit normal processing by remainder of wrapper 
																    // (unless overridden by next line of code)		
																	
																	// ***********************************************************
		  if "`cmd'"=="genplace" & "`call'"=="" local skipsave = 1    // Skip saving outcomes if 'genplace' unless 'call' is opted
																	// If 'skipsave' was not turned on above..
																	// (Skip saving outcomes if 'genpl' was not optnd with 'call')
																	// (regular 'genplace' outcomes were generated in 'genplaceO')
		  if  !`skipsave'  {											// ***********************************************************

	
	

	
	
	
	
global errloc "wrapper(8)"										    // This codeblock is only executed if 'skipsave' is not true
pause(8)				

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
	  		
		
*	  *******
	  restore														// Here finish with working contxt, briefly restore full workng data
*	  *******														// (briefly unless this is the final context)
 
 
	
	
	
*	  *******************
	  } //next context (`c')											// Repeat while there are any more contexts to be processed
*	  *******************
		
		
		
		
	  if "`noobslst'"!=""  {
		local msg = "No observations in context varlist(s):`noobslst'"
		local msg = substr("`msg'",1,strlen("`msg'")-1)				// Remove final ";" from `msg'
		errexit "`msg'"
		exit 1
	  }
	

	


*	  ********************	
	  if "`spdtst'"==""  {											// If we are NOT testing speed of simpler code ...
*	  ********************											// ****************************************************************
																	// INCLUDE (8.1) IF MINIMIZNG N OF TIMES EACH CNTXT IS SAVED/USED	***
																	// ****************************************************************

																	
global errloc "wrapper(8.1)"
pause(8.1)

	
										// (8.1) After processng last contxt (codeblk 7-8), post-process outcome data for mergng w orignl
										//	     (saved) data. AT THIS POINT THE DATA IN MEMORY ARE THE FULL WORKING DATA SUBSET
										
*	  *****************												// ****************************************************************
	  if !`skipsave'  {												// Skip this codeblock if conditions for executing it are not met
*	  *****************												// (skipped only for genplace cmd with no 'call' option)
																	// ****************************************************************
																	
		 if "`multiCntxt'"!=""  {									// If there ARE multi-contexts (local is not empty) ...
																	// Collect up & append files saved for each contxt in codeblk (8)
*			********												// (If there was only one context then just one was saved)
		    preserve												// Need to preserve again so as to append contexts to $wraptemp file
*			********

			  use $wraptemp, clear									// USE 1ST DATASET CONTAINING `cmd'P-PROCESSED DATA FOR FIRST CONTXT

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

*			*******													// (for all contexts, each context separately appended above)
			restore													// Restore the working dataset for the final context
*			*******
		
*			erase $wraptemp											// Need to keep until after merge
																	
		   
		  } //endif `multiCntxt'									// If not a multicontext dataset the one file is all there is
	  
	  
*	    *********************
	    } //endif !'skipsave'										// (skipped only for genplace commands with no 'call' option)
*	    *********************
 
 
*	******************
    } //endif 'spdtst'												// END OF CODEBLOCK THAT MINIMIZES N OF TIMES FILES ARE OUTPUT/USED
*	******************	
	
	
	
	

	
	
global errloc "wrapper(9)"	
pause(9)

												//		******************************************************************************
												// (9)  Recover `origdta', then the previous names of variables temporarily renamed to  
												//		avoid naming conflicts; merge new vars, created in `cmd'P, with original data
												//		******************************************************************************
												
												
*	*****************												
	if !`skipsave'  {										// Skip next codeblk if 'cmd' is 'genplace' without 'call' option
*	*****************



*	   ****************************										
	   quietly use $origdta, clear							// Retrieve original data to merge with new vars in $wraptemp 
*	   ****************************							// (vars built in 'cmd'P from vars in 'multivarlst)
															// If we skipped the saves, above, then we don't make any changes
															// (everything from codeblk 8 onward was just cosmetic in that case)

															

global errloc "wrapper(10)"
pause(10)	  



	  
*	   *****************	  
	   quietly merge 1:m SMorigunit using $wrapbld, nogen update replace // Different name for same file as $wraptemp
*	   *****************									// Here merge the full working dta file w all cntxts back into `origdta'
															// (bringing with it the prefixed outcome vars built from 'multivarlst'

*		**************
		erase $wrapbld 										// This should be the final tempfile to be erased
*		**************					
	  
	  

	  
*	*********************	  
	} //endif !`skipsave'
*	*********************
	
	
	if "$busydots"!="" noisily display " "					// Override 'continue' following final busy dot(s)
	




	if "`cmd'"!="genstacks"  {								// Genstacks has its own cleanup codeblocks

		local optionsP : char _dta[OPTIONS1]
		
*		**************************							// Cleans up outcome data (labeling, rounding, prefixing, etc.)
		cleanup ,  `optionsP'				 				// (called w `optionsP' so it can parse the options for current command
		if "$SMreport"!=""  exit 1							// 'exit' cmd returns to caller, skipping rest of wrappr incldng skipcapture
*		**************************							// 'SMreport' is only set by errexit, so this tells us there was an error

	}						
 
 
	local skipcapture = "skip"								// If execution passes thru this point there was no error in capture blocks
	

* **************
 } //endcapture											// Close brace matching the 'capture noisily {' at start of program	
* **************
 
if _rc  exit _rc											// Apparently, a non-zero RC does not survive a higher-level end capture	***
															// COMMENTED OUT TO SEE IF NUMEROUS NEW 'exit 1' CMDS, ABOVE, DO THE TRICK
															// (apparently not!)
	
	
	
pause(11)											// SEEMINGLY SO!
global errloc "wrapper(11)"


										// (11) Handle any non-zero return codes from above (including called programs)
										// 		Drop all globals except those needed by caller ('multivarlst') & succeeding commands

															
  if _rc  & "`skipcapture'"=="" & "$SMreport"=="" {			// If unreported non-zero return code (should be captured Stata error)
															// (meaning that nature of error will not already have been displayed)
	 errexit "Likely user error in $errloc"					// If no return code, likely user error
	 exit 1

  } //endif _rc & ...
  
  
  global limitdiag : char _dta[LIMITDIAG]					// Reset "$limitdiag" so need not do so in every caller cmd 
															// (saved in _dta charactrstc `cos globals get lost with preserve/restore)
  
* *****************************
  if "`cmd'"=="genstacks"  exit								// If this is cmd 'genstacks' we return to its caller for cleanup
* *****************************								// (and following commands are executed at the end of THAT subprogram)

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
															//  PARSING $multivarlst AS WE DO NOW
	exit
															// HOPEFULLY AVOIDS SPURIOUS 'matching close brace not found' ERROR
} //end capture												// End of braces that capture any errors over entire wrapper
	
	
	
	
end //stackmeWrapper										// Here return to `cmd' caller for data post-processing




************************************************* end stackmeWrapper ****************************************************************








**************************************************** BEGIN SUBPROGRAMS **************************************************************
*
* Table of contents
*
* Subprogram			Called from						Task & notes (just one argument in quotes unless otherwise noted)
* ----------			-----------						------------
* checkSM				Wrapper(0.3)					Establish list of SMvars (a.k.a. special names) referenced by user
*													 Note: "text" [or "noexit"] prevents call on 'errexit' from 'checkSM' on error
* checkvars				Wrapper(0.3), subprograms 		Alternative for unab that handles mixed hyphenated and abbreviated varnames
*													 Note: "text" [or "noexit"] prevents call on 'errexit' from 'chackvars' on error] 
* cleanup				Wrapper(10) excpt for genstacks	Cleans up outcome data after processing (labeling, rounding, prefixing, etc.)
* dispLine				Wrapper, showdiag2, others		Displays text message in Results window with optimized line-breaks
* errexit				Everywhere						Displays error msg in 'note' window; optionally also in Results window 
*													 Note: 'arg "msg" ' | opts ', msg(txt of msg)' rc() display(requird to display msg)
* getoutcmnames			getprfxdvars, cleanup(10)
* getprfxdvars			Wrapper(5); cleanup(10)			Initialize outcome variables as required by each command
*													 Note: 'outcomes, options' lets program identify optioned outcome prefix-strings
* getwtvars				Wrapper(2)						Establish weight string for each nvarlst in a multivarlist
* isnewvar				Wrapper(various)				See if vars [w optioned prefix-string] already exist
* showdiag1				Wrapper(6)						Store diagnostic stats before calling 'cmd'P
* showdiag2				Wrapper(7)						Display diagnostic stats after return from 'cmd'P
* stubsImpliedByVars	genstacksO (twice)				Name says it
* varsImpliedByStubs	genstacksO, cleanup				Name says it
*
********************************************************************************************************************************







********************************************************************************************************************************



* THIS VERSION RETRIEVED FROM stackmeWrapper2c TO REPLACE MISGUIDED ATTEMPT AT DUPLICATING JOB OF `genstacksO', COMMENTED OUT BELOW

																	 
capture program drop checkvars					// Called from wrapper and several subprograms; elaborates Stata's 'unab' command
												// (Should be renamed 'unablist' for "unab list of vars")
		
program checkvars, rclass						// Checks for valid input/outcome vars. Partially overcomes intermittant
												//  error when unab is presented with a hyphentated list of varnames
												// (with hyphentd AND non-hyphenated it can wrongly send non-zero return code)
												// ("partially" because 'unablist' exits on first bad 'var-to-var' varlist, whereas
												//	the whole point of this subprogram is to build a list of all bad varnames)
												// In practice all bad varnames are listed unless interrupted by bad var-to-var
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
				if "`var'"!="`opt1"	{							// CLUGE AVOIDS ERROR EXIT DUE TO MISSPELLED "`opt1" 					***
					local errlst = "`errlst' `var'"				// Add that invalid var to 'errlst' if not missing
				}												// A CORRECTLY SPELLED VERSION OF `opt1' WAS ALREADY APPROVED			***
			}
			else local checked = "`checked' `var'"				// Else add that valid `var' to 'checked'
		} //next `var'
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
				errexit "Cannot process `t12vars' – perhaps non-var or in wrong order?"
*						 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				exit 1											// In this case, override `noexit' argument, if any
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
		
	if "`errlst'"!="" & "`noexit'"==""  {						// If any bad varnames were identified (but not anticipated) ...
		
		dispLine "Invalid variable name(s): `errlst'" "aserr"	// May need multiple lines to display this error message
		if "`noexit'"==""  {									// If `noexit' was not optioned on call to this subprogram..
			errexit, msg("Invalid variable name(s): `errlst'")	// Then exit with stopbox message but no addtional display
			exit 1												// 'errexit' w opt & w'out ',display' suppresses display
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
       exit _rc
    }
														

end checkvars




****************************************************** end checkSM ******************************************************************





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
															// NOTE THAT WHILE OPTIONS MOSTLY REMAIN UNCHANGED OVER SUCCESSIVE VAR-
															// LISTS, SEVERAL COMMANDS ALLOW THE FIST OPTION (WHATEVER IT MIGHT BE)
															// TO BE ESTABLISHED OR UPDATED BY A VAR-PREFIX PREPENDED TO THE FIRST 
															//  PRFXVAR – PERHAPS ITSELF PREFIXED BY A PREFIX-STRING)
	local errloc = "$errloc"								// (NOT DOCUMENTED IN VERSION 10)
	local cmd = "$cmd"
															

	local varlistno : char _dta[VARLISTNO]					// Provides, for each outcmname, the varlist# where that name originated
	local namechange : char _dta[NAMECHANGE]				// Char stored in 'getprfxdvars', below; governs tempvar renamng in blk(4)
	local statrtrn : char _dta[STATRTRN]					// BOTH OF THESE ARE SPECIFIC TO CMD 'genmeanstats'
	local statprfx : char _dta[STATPRFX]					// (line up with pre-wrappr(3) scalrs `cos both were created sequantially)
	local limitdiag : char _dta[LIMITDIAG]					// RETRIEVE CHARACTRSTCS; ONCE WERE IN GLOBALS BUT ARE NOW ARE IN SCALARS
	local nvarlsts : char _dta[NVARLISTS]					// Retrieve N of local varnames
	local outcmnames : char _dta[OUTCMNAMES]				// There are as many`outcmnames' as there are different outcome prfxs
	local inputnames : char _dta[INPUTNAMES]				// There are as many`inputnames' as there are different outcome prfxs
	local stubnames : char _dta[STUBNAMES]					// Same for the `gendummies' `stubnames' if STUBNAMES is not missing
	local varstubs : char _dta[VARSTUBS]
	local prfxvars : char _dta[PRFXNAMES]					// Ditto (CALLING THEM prfxvars IS UNFORTUNATE LEGACY NAMING CHOICE)		***
	local optnames : char _dta[OPTNAMES]					// Save having to initialize these again for this subprogram
	global interims : char _dta[INTERIMS]					// So far used only by gendummiesP to communicate interims with 'cleanup'
	local spfxlst : char _dta[SPFXLST]						// ('genme' has the same multiplier in regard to stat names in $statlst)
															// (don't confuse with `strprfx'; derived from scalar set before wrapper(3))
															// ADDITIONL LOCALS ARE DERIVED FROM CHARS SPECIFIC TO EACH `nvarlst', BELOW

local show = "inputnames: `inputnames'; outcmnames: `outcmnames'; stubnames: `stubnames'; varstubs: `varstubs'"


							
pause cleanup(0)											// Establish general location of any error that may be captured below
global errloc "cleanUp(0)"									// Currently executing codeblock helps diagnose program & user errors
pause off


										
* *****************
  capture noisily {											// Open brace for codeblocks where errors will be captured, to be
* *****************											//  processed following the matching close brace at and of subprogram

									
										// (0)   Reduce all prefix-strinhs to single- or double-char; then prepare for labeling vars 
										//		 appropriately, given input and outcome characteristics (these options remain in force 
										//		 for all varlists used in this cmd (any updating of the first option for each command 
										//		 will be handled seperately for each var-list, below).	
										// 		   Discover what prefixes will have been used for interim variabls generatd by this cmd's
										//		 `cmd'P subprogram. Determine if any of them are all-missing for all contexts, so that
										//		 such vars can be skipped for the remainder of this `cmd' (also used for diagnostics).
										//		 Establish various foundations on which to build outcome variable labels. Display 
										//		 optioned choices regarding `replace' optn; 
										
	
					
	if "`cmd'"=="genmeanstats"  local spfxlst ="`statprfx'" // If this is a 'genme' cmd, labelng items from "$statrtrn", set after above
															
	local interims = ""										// NEXT CODEBLK WILL PRODUCE `cmd'P-GENERATED INTERIM NAMES FOR THIS LIST
															// "`multivariate'", next line, subsumes "`cmd'"=="genyhats"
	if "`cmd'"=="gendummies"  {
		local interims : char _dta[INTERIMS] 				// This is the only cmd that globlizes its interm names
    }
															
	else  {													// For other commands the list of interims can be constructed for each `nvl'
															// (other cmds where interim `cmd'P names have a stndrd prefix pre-inputname)
															// (will define the default estimation model for each varlist)
	  local k = 0											// Needed to keep track of `inputvar' locations and for checsum diagnostic
	  
															// WE KNOW THAT A`cmd'P-GENERATED INTERIM VARIABLE HAS AT LEAST ONE PREFIX
	  forvalues nvl = 1/`nvarlsts' 	{						// Cycle thru varlists in current command
	  
		 local 0 : char _dta[OPTIONS`nvl']					// Put OPTLIST char for this varlist into `0' where `syntax' expcts it to be
		 local mask : char _dta[MASK`nvl']					// Ditto for `mask' (both now are fully spelled out 3-char uppr case version)
															// (originl versn of options was named _dta[OPTIONS]; name of mask was same)
*		 *******************************															
		 syntax [anything] [if] [in] [fw aw pw iw/], [ `mask'`nvl'  * ] // Re-parse the mask for whichever 'cmd' is currently in progress
*		 *******************************					// Options like `dprefix' `itemname' and `round' are acquired in this way

		 local multivariate: char _dta[MULTIVARIATE`nvl']
															// This is the varlist-specific version of cnar MULTIVARIATE refrncd above
		 local varlist : char _dta[VARLISTS`nvl']			// CHAR SAVED BEFORE WRAPPER(3) IS CLUGE TO OVERCOME LOST GLOBAL

		 local nv = 1										// Count of position in varlist of variable `inputnames`k'
		 
		 foreach no  of  local varlistno  {					// `no' is the varlist# where each `inputname' originated
															// (several identical `no's per `nvl' – so we look for next failure to match)
			if `no'!=`nvl' continue							// Continue with next `no' if this one is not same as `nvl'
															// Else found (anothr) match; interims are built on standard cnd'P inputnames
			local k = `k' + 1								// (these can be associated with more than one `no' value in each varlist)
															// (needd to find matchng wrd in corrspndng lsts of inputnames and outcmnams)
			local iname = word("`varlist'",`nv')			// Get current varname from current varlist
			if strpos("`iname'","_")  {						// If `iname'" contains a "_" charactr then varname follows "_"-suffixed str
			   gettoken head tail : iname, parse("_")		// Parse into `head' and `tail' around "_"
			   if substr("`tail'",2,.)!= word("`inputnames'",`k')  local nv = `nv' + 1 // And see if `tail' matches word `k' of `input..s'
			}												// (if `tail', shorn of leadng "_" is not word `k' of`inpu..s', incremnt `nv')
			else if "`iname'" != word("`inputnames'",`k') { // Else, having no "_" within the string, see if whole word matchs inputname`k'
			   local nv = `nv' + 1							// (lack of match due to word in varlist falling behind word in `inputnames')
			}									     		// So we move on to next var in `varlist' (as we did for alt mismatch above)
			local iname = word("`inputnames'",`k')			// Either way, update `iname' to match the name in word `k' of `inputnames'
															// (NOTE that, if no mismatch, no harm is done by replacing `iname' w itself)
															
			local spfx = word("`spfxlst'",`k')				// Get the interim-producing prefix put in `spfxlst' by subprog 'getprfxdvars'
															// (it is also the prefx produced by `cmd'P, which may have embedded 2nd prefx
															// (if there was a "_" we checkd its suffx, above, rather than the whole word)
			local interim = "`spfx'_`iname'"				// Either way, get`interim' name by prefixing `iname' with this `cmd's `ic'
			local interims = "`interims' `interim'"			// (`ic', for "initial character", is referred to interchangeably with `spfx')
															// (ABOVE CODEBLOCK HAS REALLY INTRICATE LOGIC FOR WHICH I DO APOLOGIZE!)
		 } // next `no' 

	  } //next `nvl'										// This cumbersome procedure finds the `spfx' associated with that varlist
		
	  local noutcm = wordcount("`outcmnames'")
		 if `noutcm'!=`k'  {
			errexit "Checksum error in cleanup(0.2)"
			exit 1
		 }
		 
	} //end else
	
	
	
	

pause cleanup(1)
global errloc cleanup(1)
	

											// (1) HERE PREPARE TO GET PROXIMITIES FROM DISTANCES & DISPLAY USER CHOICES
	


	local prx = 0											// Whether `proximities' was optd (DONT CONFUSE WITH `pfx' FOR PREFIX)
	
	if "`proximities'"!=""  {								// This codeblk applies only to command 'gendist'
		
		local prx = 1										// Proximities will be generated in next codeblk (1.1)
			   
		if "`replace'"!=""  {
			noisily display "Proximities calculated as optioned; dropping distances per 'replace' option"
*					 		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		}
		else noisily display "Proximities calculated as optioned; distances kept since 'replace' was not optd"
	   
	} //endif 'proximities'									// Back to all 'cmds' (including 'gendist')
	

	else  {													// Else proximities are not being calculated
	   if "`replace'"!=""  noisily display "Dropping relevant input & interim vars per 'replace' option"
*					 		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
	}														// Applies to all but 'gendist' command	
 	   
	   
	   
	   
	   
							
pause cleanup(1.1)
global errloc cleanup(1.1)	


										// (1.1) Create default label based on label of input var, if not command-specific
	
	local k = 0
										
	foreach interim  of  local interims  {					// Cycle thru' all vars generated by this cmd's `cmd'P subprogram
															// (reconstructed in cleanup(0.2) above)
	  if "`multivariate'"!=""  continue, break				// If this was a multivariate yhats command we already got outcmname
	  local k = `k' + 1										// Increment the above-mentioned varlist #
	  
	  local nvl = word("`varlistno'",`k')					// `varlistno' holds varlist# from which each var was derived
	  										
	  if "`cmd'"=="gendist"  {								// If this is a 'gendist' command, prepare label content appropriately
	
		local mis = "`missing'" 							// Get missing treatment optioned by user with option `missing'
		if "`mis'"=="" local mis = "all"					// Defaults to "all" if 'missing' option was not used for any of above
		if "`mis'"=="mean" local mis = "all"				// Permit legacy keyword "mean" for what is now "all"
		if "`mis'"!="dif2" local mis = substr("`mis'",1,4)  // Keep 4 chars if those are "dif2", else just 3 chars
		if "`mis'"=="di2"  local mis = "dif2"				// (in case user thinks there is a 3-char minimum)
		if "`mis'"=="dif" local mis = "Diff"				// (ditto)
		
	  } //endif `gendist'

	  local non2missing = ""								// List of vars not missing across all varlists (for efficiency)
	  local nonmissing = ""									// Ditto across current varlist (UNSURE WHY THIS IS A GLOBAL)				***
	  local skipvars = ""									// List of vars missing for all contexts, cumulates across varlists
															// (needed to eliminate all-missing variables from the data)
		 
	  local ic = substr("`cmd'",4,1)						// Identifying char(s) used to distinguish interims produced by each `cmd'P
															// (For `cmd'==gendi `ic' is "d"; for `cmd'=="gendummies" `ic' is "du")
	  if "`cmd'"=="gendummies"|"`cmd'"=="genmeanstats"  	///
		local ic`nvl' = substr("`cmd'",4,2)						
															// (`ic' for 'genmeanstats' will have two chars identifying each stat)
	  if "`cmd'"=="genyhats"  local ic = "yb"				// For `cmd'==genyh `ic' defaults to "yb" for a bivariate etimation model
	  if "`multivariate'"!=""  local ic = "ym"				// But if `multivariate' was optioned prefix becomes "ym"
															// local ic2 will be established per intgrim prefix

	  
	  local prfxvars : char _dta[PRFXVARS`nvl']				// Get prefixvars, if any, associatd with varlstno that yieldd this interim
															// (in wrapper `prfxvar' was misleadingly singular for each varlist)	  
	  if "`prfxvars'"!=""  & "`prfxvars'"!="."  {			// If `prfxvar' is non-empty and non-missing ..
		
	    local strprfx : char _dta[PRFXSTRS`nvl']			// get any prefix string that may have prefixed the prefixvar
		if "`strprfx'"=="."  local strprfx = ""				// If missing make it empty
		if "`cmd'"=="genyhats"  {							// For 'genyhats'..
		   if "`strprfx'"=="yh"  local strprfx = "yb"		// Make the outcome name more specific (bivariate estimation by default)
		   local prfxvar : char _dta[PRFXSTRS`nvl']			// (and override the original flag in the relevant scalar)
		   local dvar = "`prfxvars'"						// 'genyh' uniquely uses the prfxstr to name the outcome variable
		}													// (else, for most cmds, prefixvars were used to generate outcmevars)
	  }	//endif `prfxvars'									// Else it is a bivariate yhat (unless user option overode default)

	  if ! strpos("gendummies" "genmeanstats","`cmd'")  {	// If `cmd' is NOT one of these two `cmd's ..
	    if strlen("`ic'")==2 local ic2 = "`ic'" 			// `ic' has interim prefix (1 or 2 chars); `ic2' has outcome prfx (2 chars)
	    else  {												// `ic' was established in (0.1)
	  	  local ic2 = "`ic'" + substr("`interim'",1,1) 		// This two-char `ic' appends interim prefix to cmd prefix
	    }													// (for commands that don't already have a two-char `ic')
	  }
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
	   
		  	local lbl = "gen`ic2'-generated outcome from input `iname': `lbl'"
															// Append that label
		} //endif _rc
		else  local lbl = "gen`ic2'-generated outcome from input `iname'"
															// Else leave input varname unlabeled at end of new label
	  } //endif `lbl'	
			
	  else  {												// Else make same label as above, using `ic2' `cos they're outcome labels

		local lbl = "gen`ic2'-generated outcome from input `iname'"
												
	  } //endif
															// ONE MORE SPECIAL CASE TO BE PROCESSED BEFORE inputs FROM OTHER CMDS:
	  if "`cmd'"=="genyhats" & "`multivariate'"!=""  {		// If this is a multivariate yhats command
															// (PROCESSED FIRST `COS COMES IN 2 FLAVORS – `bivariate' version below)
		local varlist : char _dta[VARLISTS`nvl'] 			// Retrieve varlist saved before wrapper(3)
		   local lbl : variable label `dvar'
		   if "`logit'"==""  local txt = "regression of "
		   if "`logit'"!=""  local txt = "logit from "
		   local lbl = "Yhat for `txt'`dvar' on `varlist'"  // `uniqnames' omits duplicate inputs (eg in gendu)
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
		  
*		    local distance = "`interim'"					// Save this value to use when generating any optioned proximity			***
			local lbl1 = "`mis'-based distance of `selfplace' from `iname'"
*					 	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			if "`lbl'"!=""  {								// Local `mis' was established in codeblk (0.1)
			  local lbl1 = "`mis'-based distance of `selfplace' from `iname': `lbl'"
			}
		   
		  } //endif substr
		  		  
		  
		  if substr("`interim'",1,2)=="p_"  {
			 local temp = "`mis'-based plugging values for var `iname': `lbl'"
			 local lbl1`' = strupper(substr("`temp'",1,1)) + substr("`temp'",2,.)
		  }
		  
		  
		  if substr("`interim'",1,2)=="x_"  {				// If proximities were optioned on a gendist cmd 
															
			 local lbl1 = "`mis'-based `proximity of `selfplace' to `iname': `lbl'"
			 if "`lbl'"!=""  {								// Local `mis' was established in codeblk (0.1)
			    local lbl1 = "`mis'-based proximity of `selfplace' to `iname': `lbl'"
			 }
		  } //endif `prx'
				
	  } //endif `cmd'=="gendist'							//END OF CODEBLK DEDICATED TO LABELING DISTANCES AND PROXIMITIES
	   
	   		  
		  
*	  if substr("`interim'",1,1)=="."  continue				// CONTINUE WITH NEXT INTERIM IN THIS CASE (CLUGE AS TEMP FIX FOR UKNOWN)	***
				  
				  
				  
				  
				  
				  
			
pause cleanup(1.3)
global errloc cleanup(1.3)


										// (1.3)	Now we have the "root" input var, if any, we get to our actual outcome vars
										//			(gendist and gendummies outcomes have already been labeled); we continue with
										//			 other commands in alphabetic order of their i.c.'s (identifying character(s))
				  
												
	  if "`cmd'"=="geniimpute"  {							
	  	
		 if substr("`interim'",1,2)=="i_"  {				// Remove 'interim' from list of vars used to impute it
															// (and make the result part of `lbl1')
			local lbl1 = "Missng values imputd from " + stritrim(subinstr("`interims'","`interim'","",1))
			if strlen("`lbl1'")>73 & "`addvars'"!=""  local lbl1 = substr("`lbl1'",1,73) + ".. `addvars'"
			if strlen("`lbl1'")>80  local lbl1 = substr("`lbl1'",1,78) + ".."
															// Put result in `lbl1' to be applied below
		 } //endif		
															// Interim with m_ prefix was already labaled in cleanup(1.2)
	  } //endif `cmd'
			   
	
	  if "`cmd'"=="genmeanstats"  {							// This command has a different basis for its `ic' prefixes
								  
		  local statlist = "`statrtrn'"						// From scalar in cleanup(0) repurposed to label 'genme' variables
															// (set after wrapper(3)
		  local lpfx = word("`statlist'",`k')				// `lpfx' is re-purposed as a portion of the label for a 'genme' var
															// (`statlist' was got from "$statrtrn" in cleanup(0.2) 
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
															// (the m_`var' was labeled at end of codeblk 1.1)
		  local lb2 : variable label `iname'				// Basis for outcm var labels is the existng label for corrspndng input
		  local txt = "regression of"
		  if "`logit'"!="" local txt = "logit from"
		  
		  if "`lbl2'"!=""  local lbl1 = "Yhat for `txt' `depvarname, on `iname':`lbl2'"
*					 					 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		  else  {
		  	 local lbl1 = "Yhat for `txt' `depvarname' on indep `iname'"
		  }
					
	  } //endif `cmd'										// End of codeblks for var with existing label
		  
															
	  if "`lbl1'"!="" 	{									// IF `lbl1' IS NOT EMPTY, TRUNCATE IT AS NEEDED TO FIT ON AN 80-COL LINE
															// (if IS empty this will be because this interim does not get a `lbl1')
		  if strlen("`lbl1'")>80  local lbl1 = substr("`lbl1'",1,78) + ".."
	  }
	  else local lbl1 = "`lbl'"								// Else use this fallback label when none other has been prepared above
															// (fallback label was initialized in codeblk 1.1, above)
	  
	  
*	  ****************************							// ************************************************************************
	  capture label var `interim' "`lbl1'"					// THIS IS WHERE INTERIM VARS RECEIVE THEIR LABELS (kept when renamd below)
*	  ****************************							// ************************************************************************
*								
if _rc  local labelerr = "`labelerr' `interim'"
	


		
pause cleanup(2)
global errloc cleanup(2)
pause off			
										// (2) Prepare lists of variables with no obs in any context, to be skipped as we proceed

			
															// AS WE PROCEED..
	   capture quietly count if !missing(`interim')			// Make list of all-missing interims – counts are for the entire dataset
	   if _rc  {
	   	   local counterr = "`counterr' `interim'"
	   }
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




if "`labelerr'"!=""  {
	dispLine "Labeling error with: `labelerr'"
}
if "`counterr'"!=""  {
	dispLine "`counterr'"
}
*if "`labelerr'"!="" | "`counterr'"!="" exit 1

															// (`non2missing' is legacy from when we took each varlist separately)
	local skipvars : list uniq skipvars 					// (Still here in case we later revert to that - more consistent - code)
	
	local nvars : list sizeof non2missing					 // `non2missing' relates to vars across all varlists
	  
	  

	if "`cmd'"!="genmeanstats"  {							// (missingness is tracked for all other stackMe commands)
															// (gendi's missing options were processed near top of cleanup(1))
	  if "`cmd'"=="gendummies"  local mis = "stub"
	  if "`cmd'"=="geniimpute" local mis = "imputed"		// (these remaining commands do not have an m_prefixed outcome var)
	  if "`cmd'"=="genplace" local mis = "placed"			// (they use local `miss' to customize their var labels – see below)
	  if "`cmd'"=="genstacks" local mis = "stacked"
	  if "`cmd'"=="genyhats" local mis = "predicted"
									
	} //endif `cmd'

	
	

pause cleanUp(2.1)
global errloc "cleanUp(2.1)"



										// (2.1)  NOW PREPARE STACKME VARS THAT RECORD MISSINGNESS FOR DIFFRENT CMDS
	
			 
	local ic = substr("`cmd'",4,1)							  // Identifyng char(s) used to distngsh interims producd by each `cmd'P
	
	if strpos("gendummies genmeanstats genyhats", "`cmd'") local ic = substr("`cmd'",4,2)
	
	local ic = substr("`cmd'",4,1)							  // Identifying char(s) for `cmd'P-generated interim vars for current cmd
	if "`cmd'"=="gendummies"  local ic = "du"				  // For these named commands, override the prefix established just above
	if "`cmd'"=="genyhats"  local ic = "yb"
	if "`multivariate'"!="" local ic = "ym"					  // THE ABOVE CODEBLOCK IS REDUNDANT BECAUSE ALL DONE PER VARLIST, EARIER
		  

	foreach ic in d i yb ym  {								  // Cycle thru `ic's for all vars for which missingness is monitored

	  foreach SMvar in `ic'misPlugCount SM`ic'misCount SM {   // Cycle thru the two summary measures for current command
															  // (using identirying char(s) (`ic') to differentiate variables)
															 
	    if "`ic'"!="d" & "`ic'"!="i" & "`SMvar'"=="SM`ic'misPlugCount" continue, break // Only have misPlugCount for gendi & genii
															  // "d" covers both multivariate yhat and gendist outcomes
	    if "`SMvar'"=="SM`ic'misCount"  {					 
			local txt = "original"							  // Set text to be included in var label for input var
	    }
	    else {												  // else set text for outcome var
			if "`ic'"=="d" local txt = "mean-plugged"		  // (i.e. mean-plugged, imputed or y-hatted)
			if "`ic'"=="i" local txt = "imputed"
			
			if "`ic'"=="ym"  local txt = "Multivariate y-hat depvar"
			if "`ic'"=="yb"  local txt = "Bivariate y-hat indep"
			if "`ic'"=="du" local txt = "dummy"		 		  // (will overwrite any txt established when "d" was matched)
			if "`cmd'"=="genmeanstats" local txt = "stat"	  
	    }
		
	    capture confirm variable `SMvar'					 // See if variable exists from previous occurrence of same cmd
		
	    if _rc==0  {										 // If that var already exists			(THIS ALREADY DONE EARLIER?)		***
	   
		  if "`SMvar'"=="SM`ic'misPlugCount"  {			 	 // If this is first SMvar, see if 2nd also exists..
			capture confirm variable SM`ic'misCount
			if _rc==0  {								 	 // If so, store both variables in SMvar
			  local SMvar = "SM`ic'misCount SM`ic'misPlugCount"
			}		 		 							 	 // Else SMvar is just one variable (first or second in foreach list above)
		  }
		  else  local SMvar = "SM`ic'misCount"			 	 // Else this is the second (and only) SMvar
		  capture confirm variable SM`ic'misCount			 // If SM`ic'misCount exists and both are optioned then both exist
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
		
	} //next `ic'

	
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
	  	if `limitdiag'  noisily display "Bounding outcome variables by input value ranges, as optioned"

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
											
															 
	local i = 0												    // Index keeps position in `prfxlist' in sync with position in `outcomes'

	foreach oname of local outcmnames  {						// `outcmnames' is a revision of `outcmnames' reconstuctd in 'cleanup'(1)
			
		local i = `i' + 1 
		
		local spfxlst : char _dta[SPFXLST]
		if "`spfxlst'"!=""  {
		  local pfx = word("`spfxlst'",`i')					    // Get prefix for this variable (from scalar saved in wrapper(3))
		  if "`cmd'"=="genmeanstats"  local pfx = word("`statprfx'",`i')  
		  if "`cmd'"=="gendist" & "`pfx'"=="x"  {
		    if "`proximities'"==""  continue  				    // Continue with next `oname' if `pfx=="x"' but proximities not optioned
		  }
		}													    // THERE SHOULD BE A BETTER LOCATION FOR THIS CHECK, IF NEEDED				***
		
		local iname = word("`inputnames'",`i')					// Get the original input name that the user typed 
		local interim = word("`interims'",`i')				    // Put the `cmd'P-genratd interim name into `interim' (saved in cleanup(1.1))		

		if strpos("`skipvars'","`interim'")  continue			// If interim with this name has no observations, skip to next var
		
/*		if "`var'"!=""  {										// If `var' is not empty then there is a prefix (BUT `var' IS ALWAYS EMPTY!)***
			if "`pfx'_"!="`ic'_"  local out ="`ic'`oname'" 		// Here we add the missing `ic' prefix (see comment block above), if needed
		}														// (only if the input name is prefixed)
*/
		if "`cmd'"!="genmeanstats"  {							// If `cmd' is NOT genme, determine whether should be renamed
																// (genme already has its final names, subject to user option)
		   if "`cmd'"=="gendummies"  {
		   	  local s = strpos("`oname'","_") + 1
		      if "`noduprefix'"!="" local oname = substr("`oname'",`s',.) // If `noduprefix' was optioned, 'gendu' now has no prefix
		   }   
		   if "`interim'"!="`oname'"  {			   				// Don't rename if `oname' is same as `pfx'_`iname'

			  capture confirm variable `oname'					   
			  if _rc==0  drop `oname'							// SOMEHOW A PREVIOUS `oname' CAN STILL EXIST (SHLD HAVE REPORTD ERROR?)	***	
								
*			  *********************								// `oname' already has the needed intricately-constructed outcome prefix
			  rename `interim' `oname'							// `oname' is a revision of `outcmname' reconstucted in cleanup(1))
*			  *********************								// `interim' is the varname that, in this case, may need a prefix added

		    } //endif `interim'
		   
		} //endif `cmd'
		
																// NOW RENAME VARS W QUASI-TEMPORARY ___(triple underline) PREFIXES
																// SINCE NAME CONFLCTS HAVE NOW BEEN RESOLVD
		if "`namechange'" !=""	{								// If, before merging with 'origdta' we changed the names of certain vars
																// (done in subprogram 'getprfxdvars'<-'wrapper' to avoid merge conflicts)
		   foreach temp  of  local namechange  {				// Here we undo those name changes
															
		      capture confirm variable `temp'					// DK WHY WE NEED THIS CHECK?												***
		      if _rc ==0  {										// If return code indicates this is an existing variable
																// (quasi-temporary ("___" prefixed) permitted co-existence or renamed vars
			     local var = substr("`temp'",4,.)				//   with those that previously had that name)

*			     *******************
			     rename `temp' `var'							// Rename the quasi-temp var to have the same suffix but no "___" prefix
*			     *******************

		      } //endif _rc  									// (WHAT ONCE WAS GLOBAL namechange IS NOW HELD AS SCALAR NAMECHANGE)		*** 
		   
		   } //next temp
		
        } // endif namechange 

											
			
		char define `oname'[origvar] `iname'					// Record origin of outcome var in terms of input varname
		local shortcmd = substr("`cmd'",1,5)					// Produce a short-form command name (first 5 characters)
		local cumulate : char `iname'[cumulate]						// Get prior cumulated list of `shortcmd's from char `iname'[cumulate]
		if "`cumulate'"=="" local cumulate = "`shortcmd'"		// (may be empty if first in cumulating list)
		if "`cumulate'"!="" local cumulate = "`cumulate' `shortcmd'"
		char define `oname'[cumulate] `cumulate' `shortcmd' 

		
	} //next oname
	
	

	if "`skipvars'"!="" & "`skipvars'"!="."  {				// If there were any vars with no observations for any context..
		
		local skipvars = strtrim(stritrim("`skipvars'"))
		local skipvars : list uniq skipvars					// Remove duplicates from `skipvars'

		dispLine "For variables listed here, no valid observations were found in any context: `skipvars'; continue anyway?"
*				  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		local rmsg = "`r(msg)'"
		
		capture window stopbox rusure "`rmsg'"
		if _rc  {
			errexit "Lacking permission to continue anyway, will exit on 'ok'"
			exit 1
		}
*		else  drop `skipvars'

	} //endif `skipvars'
	
  
    local skipcapture = "skip"							 	// In case there is a trailing non-zero return code
															// (his cmd executes if there was no error between the capture braces
	
*  *************											 *************************************************************************
capture  } //endcapture										 // Close brace enclosing code, back to top, whose errors will be captured
*  *************											 // (any error found there will cause execution to skip to following code)
*														  	 *************************************************************************
*capture }													 // Cluge avoids "close brace not found" on error exit
															 // COMMENTED OUT 'COS ONLY OCCURS WHEN `errexit' EXITS 'if' BEFORE ENDIF
	
  if _rc & "`skipcapture'"==""  {
  	
	errexit "Stata has diagnosed a program error in 'cleanup'"
	exit _rc
	
  }
  
exit 														// Needed if extra } is provided			
															// PROBLEM SEEMS TO ARISE FROM ERROR EXIT IN COURSE OF AN IF/ENDIF CLAUSE
															
end cleanUp
	

	
	
*************************************************** end cleanup **********************************************************************




capture program drop dispLine					 // Called from errexit and elsewhere (in lieu of calling errexit)

program define dispLine, rclass					 //`msg' text is divided in two at ";" if any. What starts with ";" is appended to
												 //  (abbreviated) text if `msg' does not fit in optioned # of lines (3 by default) 
												
args msg aserr maxlines							

												
if "$errloc"!="errexit" global errloc "dispLine" // Don't record this $errloc if previous $errloc was 'errexi'

if "$busydots"!=""  noisily display " {txt}"	 // If previous display ended with _continue, display a blank line

if "`maxlines'"==""  local maxlines = 3			 // By default, display up to three 80-column lines (to change `maxlines', 2nd option
												 //  must be "aserr" or some other non-empty string); use "aserr" string for 'display
												 //  as error' – otherwise use, e.g. "noerr", if `maxlines' is to be optioned.
*****************
capture noisily  {								 // Any error occurring before corresponding close brace will be captured
*****************								 // (and processed after that close brace)
	
  gettoken msg last : msg, parse(";") 						// If `msg' contains ";", that and rest of `msg' will suffix (abbrv) txt
  if strpos("`msg'","`last'")  local last = ""				// If `last' repeats `msg' content, make `last' empty
  local allmsg = "`msg'"									// (leaves `msg' shorn of terminal "last", for use with r(return))
															
  if "`last'"!=""  local lenl = strlen("`last'")			// Length of suffix determines max length of final line to be displayed
  else local lenl = 0										// Make `lenl' =0 if there is no suffix
  local maxwidth = 80 - `lenl'								// `maxwidth' is max width of final line displayed, when suffix is added
  local maxwidnl = 81										// `maxwidnl' is max width of any non-final line (line with no suffix)

  local lnc = 1												// Initialize linecount of line being displayed
  
  while strlen("`msg'")>`maxwidnl' {						// While 'msg' (including final `last' if any) extends beyond `maxwidth'
															// (need space for final "?" if any)
	local lastsp = strrpos(substr("`msg'",1,81)," ")		// Find last space in 81-char substring (note the two "r"s in `strrpos') 
															// (if there is a space at 81st char, that is fine)
	local line = substr("`msg'",1,`lastsp'-1)				// (`lastsp` could be 81, in which case we would have an 80-column line)
	if"`aserr'"=="aserr" noisily display "{err}`line'{txt}" // Display this line 'as error' if optioned (no `last' appended)
	else  noisily display "{txt}`line'{txt}"				// Else display it noisily (last line will be displayed after endwhile)
	
	local msg = substr("`msg'",`lastsp'+1, .)				// Trim from head of `msg' what was just displayed, plus final space
	if strlen("`msg'")<=(80-`lenl')  continue, break 		// If chars left to display are < available chars, break out of loop
															// Else see if additional lines can be displayed
	local i = ""											// Will be used for possible subtraction, below
	local lnc = `lnc' + 1									// Increment linecount for line that will be displayed next
	if `lnc'>=`maxlines' & strlen("`msg'") > 80-`lenl'  {	// If this count >= `maxlines' and > 80 chars are left in `msg'+suffix
	  if substr("`msg'",-1,1)==" "  local i = "-1"
	  local msg =substr("`msg'",1,(80-`lenl'-2`i'))			// Trim rest of `msg' beyond what fits currnt ln; append "..`last'"
	  continue, break										// That string should fit, so break out of loop to print it
	}														// (NOTE that `last' starts with ";")
	
  } //endwhile 'msg'>`maxwidnl'
  
  
  
  if "`msg'"!=""  {											// If there are any characters left un-displayed (reached end of `msg')
 	if substr("`msg'",-1,1)==" "  local msg = substr("`msg'",1,strlen("`msg'")-1) // Trim off final char if it is blank 

	
	if "`aserr'"=="aserr" noisily display "{err}`msg'..`last'{txt}" // Display final (or only) line +`last' as error if optioned
	else noisily display "{txt}`msg'..`last'{txt}"					// Else display it noisily  
  
  } //endif `msg'
  
															// Now return the entire trimmed message for caller`s' optional use
															
  local maxchars = `maxlines' * 80							// Find max chars corresponding to optioned (or default) max lines
  
  if strlen("`allmsg'")>`maxchars'  {						// IF STRING IS TOO LONG ..
  	 local msg = strrtrim(substr("`allmsg'",1,`maxchars'-`lenl')) 
	 local lastsp =strrpos(substr("`msg'",1,`maxchars')," ") // Find last space in `maxchars' substr (note the two "r"s in `strrpos') 
	 local msg = substr("`msg'",1,`lastsp'-1) + ".." + "; `last'"
  }	//endif													// Construct abbreviated `msg' to be returned
  
  else  {													// Else construct full message to be returned
	 if substr("`allmsg'",-1,1)!=" " local allmsg = "`allmsg'" // Add space at end of `line', if needed
  	 local msg = "`allmsg'`last'"
  }	
  
  return local msg `msg'									// Return reformatted msg to caller, for optnl use in 'window stopbox' call
  
*  if substr("`msg'",-15,.)=="will exit on OK" 				// Break exit if reported that would exit
  
  local skipcapture = "skip"								// If execution passes this point, no error was captured

  
  
************** 
} //endcapture
**************



if _rc & "`skipcapture'"==""  {
  errexit "Stata has diagnosed a program error within 'dispLine'"
  exit _rc
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
	scalar SMmsg = "`msg'"						// Save in a scalar the 'msg' argument or option passed to this cmd
	scalar ERRLOC = "$errloc"					// Ditto for $errloc
	scalar EXIT = "$exit"						// Ditto for $exit
	macro drop _all								// Clear all macros before exit (evidently including all of the above)
	capture drop ___*							// Drop all quasi-temporary vars (vars with names starting "___")
												// (note that scalars are not macros so they are not dropped by above command)
	global SMrc = SMrc							// Get $SMrc back from its scalar copy
	local msg = SMmsg							// Governs way in whicn msgs are displayed
	global errloc = ERRLOC						// $errloc is needed by caller program, re-entered after wrapper 'end' command
	global exit = EXIT							// Ditto for $exit

	global SMreport = "reported"				// Flag, set here to survive above code, averts duplcte report from calling prog
	local limitdiag : char _dta[LIMITDIAG]
		
		
	if "$SMrc"!=""  {							// IF ERREXIT WAS CALLED BY A stackMe PROGRAM WITH KNOWLEDGE OF A STATA ERROR..
	   capture confirm number $SMrc 			// See if it was a numeric return code
	   if _rc  {								// Not numeric so "$SMrc" holds the command line that caused the error
	   
		  if "`msg'"==""  local msg = "Stata reports likely data error in $errloc"  
		  if DISPLAY !=""  display as error "`msg'{txt}" // (DISPLAY is a scalar flag, set on entry to this SUBprogram)
		  
		  if strpos("`msg'","blue")==0 window stopbox note "`msg'; will exit on 'OK'" // Version if no "return code" in 'msg'
		  else window stopbox note "`loc2'`msg' – click on blue return code for details; will exit on 'OK'" // Else this version
		  "$SMrc"								// Invoke the command line that caused the error, so Stata reports the RC
	   } 
	
	   else  {									// Else $SMrc is numeric so likely a captured return code
		 if $SMrc!=0  {
		   if "`msg'"==""  {					// IF `msg' IS EMPTY THEN THERE IS ONLY A RETURN CODE
		  	 noisily display "Likely program error `rc' in $errloc – click on return code for details" 
*		   					  12345678901234567890123456789012345678901234567890123456789012345678901234567890 
			 window stopbox note "Likely program error `rc' in $errloc – click on return code for details"
			 exit 1
		   } //endif `msg'
		   else  {								// Else there was a message with the return code
			 dispLine "`msg'; will exit on OK" "aserr" // limit to 1 line of text displayed in output window
			 local stop = "stop"
			 window stopbox stop "`msg'; will exit on 'OK'"
			 exit 1
		   }       								// No effective limit for stopbox display
		 } //endif $SMrc
		 else  {								// Else return code IS zero so display and DON'T EXIT
		 	dispLine "`msg'; continue anyway?"  // limit to 1 line of text displayed in output window
			capture window stopbox rusure "`msg'; continue anyway?"
			if _rc  exit 1
		 }
		    
		} //endelse  $SMrc
		
		scalar DISPLAY = ""						// Ensure message is not displayed again below
		
	} //endif $SMrc
	
		  
	if DISPLAY !=""  {							// IF DISPLAY SCALAR FLAG WAS SET NON-EMPTY earlier in program..
	
	   if "`msg'"!=""  {	
		  if strpos("`msg'","click")  { 		// If 'msg' contains a 'click on blue..' clause
			 display as error "`msg'"
			 window stopbox note "`msg'; will exit on 'OK'" 
			 exit 1				  				// Above will be displayed if there was no "return code" in 'msg'			***
		  }
												// Else this is a standard errorexit with two variants ..
												// If `msg' is non-empty, add "in $errloc" and "will exit on 'OK' as needed
		  if strpos("`msg'","$errloc")==0  local msg = "`msg' (in $errloc)"	    // Add " (in $errloc)" if not already there
		  if strpos("`msg'","permission to") & ! strpos("`msg'","will exit")  { // Add "will exit" if ditto
			 dispLine "`msg'; will exit on 'OK'" "aserr" 1	// limit to 1 line of text displayed in output window
			 window stopbox note "`msg'; will exit on 'OK'" // No limit for stopbox display
			 exit 1
		  } //endif
		  else  {
		  	 dispLine "`msg'"
			 window stopbox note "`r(err)'"
			 exit 1
		  }
		  
	   } //endif `msg'
	   
	} //endif DISPLAY	
	

	capture confirm exists FILENAME				// If FILENAME does not exist all of following were pewsumbly dropped already
	if _rc==0  {
	   scalar drop SMmsg FILENAME DIRPATH ERRLOC EXIT
	}											// Drop scalars used to secure above macros (not including scalar display)
	exit										// Exit 0 will be turned into exit 1 (a BREAK exit) for final exit
	
	local skipcapture = "skip"					// Flag to skip capture code if that code was entered from here
												// REDUNDANT SINCE EXECUTION CANNOT GET BEYOND HERE UNLESS ERR WAS CAPTURED?

***************
} //endcapture									// End of codeblock within which errors will be captured
***************




if  _rc & "`skipcapture'"==""  {				// If entered this block without 'skipcapture' being set, 2 lines up, ..
												// (that means the error occurred in the captured part of above code)
	if "`stop'"!="" exit _rc					// `stop' was flagged if 'stopbox stop' was called, above
	noisily display as error "'errexit' diagnosed an error within itself – click on return code for details{txt}"
*					          12345678901234567890123456789012345678901234567890123456789012345678901234567890
	window stopbox note "'errexit' diagnosed an error within itself – click on return code for details"
	exit 1
}

	
end errexit


********************************************************************************************************************************



capture program drop getoutcmnames							// Called from 'getprfxdvars' (next subprogram below this one)
															// (on return to which, local inputnames, outcmnames, spfxlst become chrstcs)

program define getoutcmnames, rclass						// Returns lists of input and corresponding outcome & strprfx names
															// (outcome names already fully prefixed; others combine to make outcm names)
															// TASKS FOR THIS PROGRAM ARE LISTED AT START OF CODEBLOCK 'getoutcm(2)'
															// *********************************************************************
pause getoutcm(1)
global errloc = "getoutcm(1)"

* ****************
//  capture noisily {										// Open braces enclose code within which any error will be captured
* ****************											// (and processed after the matching close braces at end of program)

    local cmd = "$cmd"										// Make local copy of $cmd global
	
	local inputnames  =  ""									// Local that will be returned to caller w list of inputnames
	local outcmnames  =  ""									// Ditto w list of outcome names
	local spfxlst = ""										// Ditto w list of full prefix that distinguishes outcome from input name
	local newpfx = ""										// By default the user has not optioned a deviation from default usage


															
															
	
	
											// (1) GET LIST OF PREFIX-NAMES FOR CURRENT `cmd' 
											//	   (`cmd' will generate 1 var for each optname)
											
												
	if "`cmd'"=="gendist"  local optnames     = "dprefix mprefix pprefix" 	   		   // (aprefx is implmntd just before codeblk 2)
	if "`cmd'"=="gendist" & "`proximities'"!=""  local optnames = "`optnames' xprefix" // Add xprefix if "proximities" were optd
	if "`cmd'"=="gendummies"  local optnames  = "duprefix"							   
	if "`cmd'"=="geniimpute" local optnames   = "iprefix mprefix"
	if "`cmd'"=="genmeanstats" local optnames = "nprefix meanprefix sdprefix minprefix maxprefix skewprefix kurtprefix sumprefix " ///
											  + "swprefix medianprefix modeprefix" 	   // (same order as in 'genyhatsP')
	if "`cmd'"=="genplace"  local optnames    = "iprefix mprefix pprefix" 
	if "`cmd'"=="genyhats" local optnames     = "bprefix" 	// `mprefix' will be substituted (below) if `multivariate' is optioned
															// Above are prefix-naming options that may be user-invoked for each cmd	
	
	
	
	
	
	
											// (1.1) GET IDENTIFYING CHARACTER(S) FOR CURRENT CMD (i.c. – eg "d" for gendist); prepare
											//		 `aprefix'
											
											
											
	local ic = substr("`cmd'",4,1)						    // Get initial char for vars, for most of them, is 4th char
															// (for 'genmeanstats' we substitute a list of stat-names)
	if "`cmd'"=="gendummies"  local ic = "du"				// (cmd genme also has non-standard `ic' but is processed differently)
															// This prefix ultimately eliminated in 'cleanup' (3), if not user-overwrttn
															// (so does 'genyhats', dealt with in next 'if `cmd'=="genyhats"' codeblk)
	
	
	
	
	
pause getoutcm(2)
global errloc = "getoutcm(2)"
		
		
											// (2) GET VARIABLES, PREFIXVARS, STUBNAMES AND STRING-PREFIXES FOR THIS VARLIST
											

											// ***************************************************************************************
											// Prefixes cumulate as variables are augmented with dummy-variables, distance measures,
											// imputed values, and y-hats – each command prepending additional prefixes to variable 
											// names. Every variable that is deemed an outcomes from each command will have a prefix
											// that records the provenance of that stackMe-generated variable. These prefixes should
											// not be changed without careful thought regarding alternative means for keeping track of
											// variable provenance (variable characteristics NOW PROVIDE A MEANS FOR DOING SO AND WE
											// HAVE PLANS FOR AN 'origin' UTILITY THAT WOULD PUT FULL PROVENNCE INTO OUTCM VAR LABELS)
											// ****************************************************************************************
											
											
	local statprfx : char _dta[STATPRFX]					// NOTE that 'genmeanstats' 'strprfx's were saved as charctrstcs at wrapper(3)
	local statlen = wordcount("`statprfx'")					// (only one varlist is allowed with 'genme' `cos never imagined more)
	local statrtrn : char _dta[STATRTRN]					// (same length as `statprfx')	
	local nvarlsts : char _dta[NVARLISTS]					// get N of varlists from characteristics NVARLSTS set in wrapper(2.1) 

	
	forvalues nvl = 1/`nvarlsts'  {							// Cycle thru all varlists (from scalar NVARLSTS)

	  local options : char _dta[OPTLIST`nvl']				// Retrieve `options' from data characteristic OPTLIST for this varlist
															//  user-chosen for this varlist with fully spelled-out optionnames)
	  if substr(strtrim("`options'"),1,1)==","  {
	  	local 0 = "`options'"								// Replay the user-supplied options-list
	  }
*	  		***********************
	  else  local 0 = ", `options'"							// (whether or not it starts with a comma)
*			***********************							// (lack of comma corrected here)

	  local mask : char _dta[MASK`nvl']
local show = "`mask'"
	  
*	  ******************	  
	  syntax [anything] [if] [in] [fw aw pw iw/], `mask'	// `upmask' is the culled mask with upper case 1st three char optnames
*	  ******************
	  
	  local apfx = "_"										// By default `apfx' contributes the final "_" to an outcomename
	  if "`aprefix'"!=""  {									// But if `aprefix' was user-optioned..
	    if substr("`aprefix'",-1,1)=="_"  local apfx = "`aprefix'" // If user put a "_" at end of optioned prefix then keep it
	    else  {												// (need this `else' format to avoid getting a final "__" instead of "_")
		  local apfx = "`aprefix'_"							// else add the trailing "_"
		}
	  } //endif												// (if `aprefix' was optioned with trailing "_", put all of it in `apfx')
	  
	  local varlist : char _dta[VARLISTS`nvl']				// FINAL SHOT AT TRANSFERRING THIS FLAG
	  local prfxvars : char _dta[PRFXVARS`nvl'] 			// Retrieve any prefixes that are varnames (THESE DO NOT AFFECT VARNAMES)
*	  local stubnames : char _dta[VARSTUBS`nvl']			// (imperative that option `stubnames' not be schlocked by empty scalar)
															// NOW IT IS SCHLOCKED BY EMPTY char; SO COMMENTED OUT
	  local strprfx : char _dta[PRFXSTRS`nvl']				// And any string prefix to those var prefixes (1 per listof `prfxvars')
	  if "`strprfx'"=="."  local strprfx = ""				// (so it is duplicated as many times in `strprfx' as there are outcomes)
	  
local show = "varlist: `varlist'; prfxvars: `prfxvars'; stubnames: `stubnames'"	  
	  
	  if "`cmd'"=="genyhats"  {
		local dvar = "`depvarname'"							// By default this is not a `multivariate' yhats command
	    local multivariate : char _dta[MULTIVARIATE`nvl']	// (there is no `bivariate option since that is the default')
		if "`multivariate'"!="" local dvar = "`depvarname'" // (`multivariate, if optd, means using the user-optd `depvarname'	– unless
															//  overruled by existence of a prefixvar (under v9 syntax, where it is
		if "`prfxvars'"!=""  {								//  the existence of a prefixvar that tells us yhat is multivariate)
		   local dvar = "`prfxvars'"						// Multivarite genyhats generates an m-prefixd depvar by default, trumped by
		   local multivariate = "multivariate"				//  `depvarname' opt or varlist-specfc prefixvar
		   local varlist = "`dvar'"							// If multivariate 'genyh' was opted or prfxd then `varlist' provides indeps
		   local optnames = "`mprefix'"						// (and default outcome – see above – has "m_" prfx or user-optd `mprefix')
		}
	  } //endif genyhats
	  
	  
	  
	  
	  
pause getoutcm(2.1)
global errloc = "getoutcm(2.1)"




	  
	  local nv = 0											// Variable # within varlist
	  
	  foreach v  of  local varlist  {						// Cycle thru all input vars for each varlist (inputs, for multiv genyh)
	  
		 local nv = `nv' + 1								// Increment position in varlist to synchronize w prfxvars & other lists
	   
		 foreach opt  of  local optnames  {					// Go thru optionable string prefixes for current cmd (usng v1 naming)
															// (`optnames' for each command were enumerated in getoutcm(0) – `cmd' will
															//   generate one outcome variable for each optname, appropriately prefixed
			local spfx = substr("`opt'",1,1)				// For most commands, interim vars generated by `cmd'P have this prefix
															// ('opnames' names are specific to the current command – see (1) above)																  
			if "`cmd'"=="gendummies"  {						// `cmd' gendummies gets multiple varnames from the values of each var
			   local spfx = "du"							// For 'gendu', interim prefix defaults to same as default outcome prefix
			   local name = "`v'"
			   local stubs : char _dta[VARSTUBS`nv']
			   if "`stubs'"!=""  local name = word("`stubs'",`nv')
			}												// (`spfx' will have been prefixed to (prhps already prefxd )`v' by `cmd'P)
			
			if "`cmd'"=="genmeanstats" {
			   local spfx = substr("`opt'",1,2)				// For 'genme' use 1st 2 chars of cmd's current optname as interim prefix
			   if "`opt'"=="medianprefix" local spfx = "md"	// "medianprefix" has same 1st 2 chars as "meanprefix"', so disambiguate
			   if "`opt'"=="meanprefix" local spfx = "mn"	// Ditto for 'meanprefix'
															// Poor design requires repeat of 'genmeanstats' parsing done at wrapper(3)
			   if "`spfx'"=="np"  local spfx = "n"			// Need this tweak to handle single character "n" option for 'genme'
															// (short for "n of observations – the "p" was next char of optn `nprefix')
			} //endif `cmd'=='genmeanstats'					// ('gendu' and 'genme' make no use of `ic', using `spfx' instead
			
			if "`cmd'"=="genyhats"  {
			   local spfx = "b" 							// cmd genyhatsP also assigns 2-char interim prfxs
			   if "`multivariate'"!="" local spfx = "m"		// `spfx' gets interim prefix generated by 'genyhats'
			   local opfx = "y`spfx'"						// Outcome var gets a "y" in front of that interim prefix
			}
															// (so interim vars may emerge from `cmd'P with two prefixes, merged below)
			if "`strprfx'"!="" local spfx = "`strprfx'"		// Overridden by `strprfx' prefix to stub/prfxvars list, if any
															// (LEGACY CODE MAY BE USED IF WE RESTORE USE OF PREFIXVARS)
			local opfx = "`spfx'"							// The outcm prefix is based on interim prefix, unless ``opt'' was optioned
															// (see "if ``opt''..", below)
			if strpos("gendist geniimpute genplace","`cmd'") { // For these three cmds, `opfx' gets a leading character from cmd name
				local opfx = substr("`cmd'",4,1) + "`opfx'" // (gendu genme genyh prefixes already have two chars; genst makes its own)
			}												// TWO CHAR INITIAL PREFIX IS HARD TO CODE IN 'getoutcm(3), SO COMMENT OUT? ***


			
								
	
	
	
pause getoutcm(3)
global errloc = "getoutcm(3)"


											// (3) BELOW CREATE AS MANY OUTCOME VARNAMES AS REQUIRED BY N OF OPTNAMES FOR THIS CMD
											//	   (OR BY N OF VALUES FOR EACH STUB IF OUTCOME IS A SET OF DUMMY VARIABLES)

															 // ***************************************************************************
															 // Here we manage the evolution of prefix initials as a variable progresses 
															 // through the succession of stackMe commands that constitute a stackMe work-
															 // flow. There will always be at least one and no more than two prefixes, un-
															 // less a user abrogates the process by optioning a user-defined prefix (which
															 // would thereafter remain unchanged unless by user). The first prefix will be
															 // a two-char prefix constructed from the single-character cmd-specfic interim 
															 // prefix set by the current cmd's `cmd'P program, along with the current com-
															 // mand's `ic' (initl char) added by 'cleanup' accordng to a renaming template 
															 // established here in the current codeblock. The second prefix will cumulate a 
															 // record of previous stackMe commands that have shaped the variable concerned, 
															 // one character per command (generally the first of the two characters in the 
															 // previous first prefix (but, for genyhats, the second prefix ("b" or "m")). 
															 // So, with each stackMe command that is executed, the previous prefix's first 
															 // char becomes the first char of the second prefix and the replacement first 
															 // prefix becomes the two-characters defining the latest outcome var's status.
															 // Note that `gendummies' & `genmeanstats' don't contrbute to a var's history.
															 //    AT THIS POINT IN EXECUTION OF THE CURRENT COMMAND, `cmd'P has not yet put 
															 // a new prefix on the front of `v', which is still what the user typed. WHAT 
															 // WE DO HERE IS ANTICIPATE NAME CHANGES that will be made by `cleanup' so we  
															 // can see if fully prefixed variable names implied by user choices (and saved
															 // in codeblk getoutcm(3.1) below for use in `cleanup') are valid. Determining
															 // the validity of anticipated varnames is the task of codeblk getoutcm(4)).
															 // *****************************************************************************


		  local X = 0										// Logical switch specifies that a codeblk will NOT be executed for each `v'
		  local true = 1									// (based on whether their prefixes provide a historical workflow record)
		  local Y =  `true'									// Logical switch specifies that a prefix is expected			 		  
		  local false = 0									// (based on whether we already found the right `oname')
						
		  if "`cmd'"=="gendist" & strpos("d x","`spfx'")  local X =`true'	// If outcome is a primary one for 'gendist' do this codeblk
		  if "`cmd'"=="genyhats" & strpos("b m","`spfx'")  local X =`true'	// If outcome is a primry one for 'genyhats' do this codeblk
		  if "`cmd'"=="geniimpute" & strpos("i m","`spfx'") local X =`true' // If outcome is a primary one for 'geniimpute' ditto
		  if "`cmd'"=="genplace"  local X =`true'			 				// RETHINK THIS CODING DURING genplace PROG DEVELOPMENT		***
															// `spfx' is prefix generated by `cmd'P; other prefixes are not historic
															
															
*		  ********
		  if  `X'  {										// If we have the prefix string for a primary outcome variable.. 
*		  ********										    // (other prefixes are "p","m" for gendi; "m" for genii)



			local cumulate : char `v'[cumulate]				// Retrieve cumulation history (tells whether to cumulate workflow record)
															// (NOTE that this characteristic is associated with the input varname)
			if "`cumulate'"=="no"  local cumulate = ""		// Recast "yes"/"no" flag as present/empty flag (accessed at start of 3.1 )
			else  {											// (user can only indicate "no" by defining 'char _varname[cumulate] no')
			  if "`cumulate'"==""  local cumulate = "yes"   // By default will cumulate workflow history (char initially returns empty)
			}												// (cumulation is actually performed in cleanup(3), when interim vars exist)
			local oname = "`opfx'`apfx'`v'"					// For all stackMe cmds except for genstacks, the 1st prefix was set above
															// (if `cumulate' is not empty or "yes"/"no" it contains list of past cmds)

															 // **************************************************************************
															 // Local `outcmname's `ic' is `cmd-specific' prefix set by `cmd'P (if `v' has
															 // any prefixes they were put there by previous `cmd'Ps). If there are two of
															 // them the 2nd is the cumulatng prefix that will be aquiring earlier `ic's.
															 // **************************************************************************

			if "``opt''"!=""  {								 // If this optname, specific to each `cmd', was user-optioned...
															 // (signalled by non-empty ``opt'', which points to what was optioned)
			  local opfx = "``opt''"						 // Use double-quotes to access the string that the user typed
															 // (this string will replace the default `ic' prefixing an outcome varname)	
			  if substr("`opfx'",-1,1)=="_"  local opfx = substr("`opfx'",1,strlen("`opfx'")-1) 	// Remove trailing "_" if any
															 // (would duplicate the "_" provided by a default `aprefix')				
			  local cumulate = "no"							 // And set flag to indicate a user-initiated change in prefix (done below)
			} //endif ```opt'''								 // (which we will address when we have parsed the rest of the prefix	
			
			local add = ""									// By default there is as yet no prefix
			  
			local opfx = "`ic'`spfx'"						// For most commands we simply add `ic' to front of interim prefix
															// (put there by `cmd'P)
			if strpos("gendummies genmeanstats","`cmd'") {  // But for these `cmds'..
			  local newpfx = `spfx'							// We use the two-char prefix already created as interim prefix by `cmd'P
			}
			
			if "`cumulate'"!="no"  	{						// If cumulation was not terminated by user-specified outcome prefix..
												
			  gettoken frst rest : v, parse("_")			// If input has no "_" then `rest' stays empty; else gets a "_..." string 
			  if "`rest'"!=""  {							// If `v' was prefixd, we will include that prefix in `oname'(see below)
			    local rest = substr("`rest'",2,.)			// Trim the leading "_" from `rest'
				local add = substr("`frst'",1,1)			// And put into `add' the 1st character of the 2-char 1st prefix
															// (`add' will be prepended to cumulating prefix(es) preceeding 2nd "_")
			    if "`cmd'"=="gendummies"  { 				// Unless `cmd' is 'gendummies' (see below for 'genmeanstats')
			      local add = substr("`frst'",2,1) 			// (when we keep 2nd char (overwriting the 1st char, put there just above)										  
			    }
				if "`cmd'"=="genmeanstats"  local opfx = "`frst'"
*				else  {										// For 'genmeanstats' retain all of first prefix
*				  local opfx = "`ic'`add'"					// For other commands, prefix selected prefix char with `ic'
*				}											// (providing `opfx' with the 2-char prefix that is 1st prefx on all outcms)
			    if strpos(substr("`rest'",2,.),"_")  {  	// If there is ANOTHER "_" after first one.. (look beyond 1st "_" of `rest')
			      local rest = substr("`rest'",2,.)			// Strip off leading "_", parsed on far above and still at front of `rest'
				  gettoken cum rest : rest, parse("_")		// And put into `cum' the cumulating prefix that is 2nd prefix, if any
				  local rest = substr("`rest'",2,.)			// 2nd "_" will come from `apfx', which always ends with "_"
			    }											// (if `rest' had no 2nd "_")
			    local oname = "`opfx'_`add'`apfx'`rest'" 	// MONEY LINE, WHERE A PFX FROM PREVIOUS CMD IS ABSORBD INTO CUMULATNG PRFX
			  }												// (but that concatenation holds good only if `v' has a second prefix)
local show = "opfx `opfx'; add `add'; apfx `apfx'; rest `rest'"
			  else  {										// Else `rest' is empty, so not a first (or any) prefix; look no further
															// (but we still must deal with `cumulate' so we need Y to prevent overwritng)
			    local Y = `false'						 	// (we now have established an `oname' for the case where there was no prefix)
			    gettoken nxtpfx Zndrest : rest, parse("_")	// `nxtpfx' would be second prefix in front of `v', the current varname
			    if `Y'&"`Zndrest'"=="" loc oname="`opfx'`apfx'`rest'" // If there's NO 2nd prefix, `oname' needs `opfx_' before `rest'
local Zndrest = "nxtpfx `nxtpfx'; Zndrest `Zndrest'; oname `oname'"															// (this overwrites the `oname' from 'MONEY LINE')
			    if "`newpfx'"!=""  {						// (so `oname' stays unchangd as we deal with any user-optnd prefix change)
				  if "`cumulate'"!=""  {					// If `cumulate' flag is NOT empty, this is a change from previous default
															// But a change TO keepng workflow history isn't allowed
				    if `limitdiag'!=0  {					// (if displayng diagnostics give warning then continue with next var, `v')
				      dispLine "WARNING: Cannot change TO keeping prefx record of wrkflow history; use utility {help SMorigin:{ul:SMori}gin}" ///
							  aserr
				      if `Y' local oname = "`newpfx'"		// `newpfx' was established before 'if "`cumulate'"!="no"', above
				    } //endif `limitdiag'	
				  } //endif `cumulate'
				} //endif `newpfx'							// `newpfx' must be empty; so user did not option a different prefix string
			  
			  } //endelse `Istrest'							// And 2nd rest of `v' (`Zndrest') is NOT empty so is a cumulating prefix
															// (which is what we needed to confirm)
			} //endif `cumulate'
			
		  }	//endif `X'										// End of codeblk executd only for vars that keep a prfx-str wrkflow record
		  

		  else  {										 	// Outcome vars without workflow record still get an identifyng prefx
		  	 local oname = "`opfx'`apfx'`v'"				// (currently same coding as for vars w'out extant prefixes, far above)
		  }

		  
		  
		  
			
			
pause getoutcm(3.1)
global errloc = "getoutcm(3.1)"

											// (3.1) HERE WE BUILD THE LISTS OF INPUT, OUTCOME AND PREFIX ITEMS THAT WILL GOVERN
											//		 THE PREFIX-BUILDING THAT DETERMINES CHANGES TO VARIABLE NAMES AS VARIABLES
											//		 ARE GIVEN INTERIM PREFIXES BY `cmd'P AND THEN OUTCOME NAMES BY 'cleanup'
		
		  
			if strpos("gendist geniimpute","`cmd'")	{	 	  // For these commands stick `ic' character on front of `oname' prefix
			   local oname = "`oname'"						  // DK WHAT THIS IS FORMAT													***
*			   local oname = "`ic'`oname'"					  // (already done, at top of codeblk(3), for genyh) so
			}												  

			if ! strpos("gendummies genmeanstats","`cmd'") {   // ******************** 		 // If `cmd' is NOT 'gendu' or 'genme'..
*			  												   // IN THE GENERAL CASE, store `outcmnames', etc., for r-return to caller
															   // ********************
															   
															   // THE N OF OUTCOME VARS IS ONE PER OPTION, NO MATTER WHETHER USER-OPTD
				****************   *****************		   // Use input prefix (from start of `opt' loop) for `v'
				local inputnames = "`inputnames' `v'"		   // May already have a prefx, if var has already been procssd by stackMe cmd
				local spfxlst = "`spfxlst' `spfx'"		 	   // Provides prefix for `cmd'P-genratd interm (prhps already prfxd) varname
				local outcmnames = "`outcmnames' `oname'" 	   // 'opfx' is `spfx', unless overriden; `spfx' is interiim `cmd'P prefix
				local varlistno = "`varlistno' `nvl'"		   // Links outcome var to its origin in the varlist typed by user
*				****************   *****************		   // For most commands the `opfx' starts with `ic' unless overridden	
															   // (if aprefix was not optnd, outcome prefix is "`ic'_" – see above)
		    } //endif										   // (`oname' already contains `aprefix' (aka `apfx'), if optioned)

			
															 // **************************
															 // IF COMMAND IS 'gendummies' (can have several values == several outcomes)
			if "`cmd'"=="gendummies"  {						 // **************************

				local name = "`v'"							 // FOR 'gendu', N OF OUTCOME VARS IS ONE FOR EACH VALUE OF EACH INPUT VAR
															 // (`name' needed to provide for stubs either derivd from input or optiond)
*				if "`stubname'"!="" local name="`stubname'"  // Optiond stubname replaces default stubname (derived from input varname)
															 // COMMENTD OUT AS VERSN 10 PUTS OPTD STUBNAMES INTO CHAR IN wrapper(2.1)
				if "`stubnames'"!=""  {						 // If prefix `stubnames' not empty they take priority over optiond stubname
				  local name = word("`stubnames'",`nv')	 	 // Trumped by a stubname corresponding to each input variable
				}											 // (using `name' in lieu of `v' avoids possibilty of schlocking `v')
				local tlen = strlen("`name'")				 // Get length of varname pointed to by `v' or `stubname'
															 // NOTE DIFFERENCE BETWEEN SINGULAR 'stubname' AND PLURAL 'stubnames' ABOVE
				if real(substr("`name'",`tlen'-1,1))!=. { 	 // If last char of `name' is numeric (conversion to real is NOT missng)..
				   errexit "Apparent user error: a dummy input stub should NOT end with a numeric character"
				   exit 1
				} //endif
				if "`noduprefix'"!="" local spfx="`duprefix'" // (overridden if `duprefix' was user-optioned)
															// Save in list of varname prefixes used to diagnose varname conflicts
				quietly levelsof `v', local(V)				// MUST GET VALUES OF VARIABLE, NOT STUB!		  
				foreach val of local V  {				   	// For gendu we get as many outcome names as the var had values
															// (there is only one quasi-optname for gendummies)
				   capture confirm number `val' 			// Error if `val' is NOT numeric 
				   if _rc {
			          errexit "Apparent user error: a dummy outcome varname should have numeric values"
			          exit 1
				   }
				   ************************   ************	// HERE N OF OUTCOME VARS IS ONE FOR EACH VALUE OF EACH INPUT VAR
				   local inputnames = "`inputnames' `v'" 	// `inputnames' gets  varname that user typed, as many times there are values
				   local spfxlst = "`spfxlst' `spfx'"		// Always missing for gendummies SO WE DON'T USE `ipfx'
				   local outcmnames = "`outcmnames' `opfx'`apfx'`name'`val'" // 'opfx' is "du" unless overridden
				   local varlistno = "`varlistno' `nvl'"	// Links outcome var to its origin in the varlist typed by user
*				   ************************   ***********	// (`name' is unique to 'gendu', allowing `name'`val' to replace `oname')
															// (also, as with 'genme', we don't cumulate dummy variable prefixes )

				} //next `val'
				
			} //endif "`cmd'"=="gendummies"					// END OF PROCESSING FOR COMMAND 'gendummies'
			  
			  
			  
															// ****************************
			if "`cmd'"=="genmeanstats"  {					// ELSE COMMAND IS 'genmeanstats' (can have several optnames )
															// ****************************	  (we are already in optname loop)
															
															// NOTE THAT 'genmeanstats' PREFIXES, ESTABLISHED BY OPTION 'stats'
															// AFTER 'wrapper'(3), DETERMINE WHICH `optnames', CURRENTLY BEING
															// CYCLED THRU & IDENTIFIED BY `spfx', WILL GOVERN THE OPTIONAL
															// RENAMING OF THE 'genmeanstats' OUTCOME VAR BY CHANGING ITS PREFIX.
															// ******************************************************************
				if strpos("`statprfx'","`spfx'")==0 continue // Continue with next option if this one not in list of optd stats
															// (`statprfx' was established at wrapper(3) & passed in char _dta[STATPRFX])
				
				****************   ******************		 // HERE THE NUMBER OF OUTCOME VARS IS THE NUMBER OF OPTIONED STATS
				local inputnames = "`inputnames' `v1'"		 // Caller may need unadorned input varname
				local spfxlst = "`spfxlst' `spfx'"			 // 'genmeanstats' uses `stat' as prefix for `cmd'P interim names
				local outcmnames = "`outcmnames' `spfx'`apfx'`v'"  // There is no `opfx' for 'genme'; instead we use `spfx' again
				local varlistno = "`varlistno' `nvl'"		 // Links outcome var to its origin in the varlist typed by user	
*				****************   ******************		 // Note that we do not cumulate genme prefixes
													

			} //endif `cmd'=="genmeanstats"				 // END OF PROCESSING FOR COMMAND 'genmeanstats'
			 
			local spfx = ""								 // Empty this in case next var has no user-optioned prefix

		  } //next `opt'
		  
	   } //next 'v'
	  
	  
	} //next 'nvl'
	

	
	
	
	
*pause on
pause getoutcm(4)
global errloc = "getoutcm(4)"
pause off	
	
											// (4) CHECK FOR DUPLICATE OUTCOME NAMES AND DROP IF USER PERMITS
											
// IN PRACTICE, FOR UNKNOWN REASONS, ALL OUTCOME NAMES ARE DUPLICATED -- FIND OUT WHY OR USE THIS CODE AS CLUGE TO ELIMINATE DUPS		***
											
											
												
	local dups : list dups outcmnames						// 'list dups' returns list of outcome names that are duplicates
															// (see below for check of whether outcome name duplicates existing name)
	if "`dups'"!=""  {

// HERE IS CLUGE OMITTING REPORT OF DUPLICATE OUTCOME NAMES BY COMMENTING OUT NEXT SIX LINES											***
/*
		dispLine "You have specified duplicate outcome names: `dups'; drop excess names?"
*				  12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		local rmsg = r(msg)
		capture window stopbox rusure "`rmsg'"
		if _rc  {
			errexit "Lacking permission to drop duplicate outcome varnames, will exit on OK"
			exit 0
		}													// Else drop these dups one-at-a time, first to last
*/
		while wordcount("`dups'")>0  {						// While there are any duplicates
			local isdup = word("`dups'",1)					// Drop one copy of first duplicate name (substitute "" for it)
			local outcmnames = stritrim(subinstr("`outcmnames'","`isdup'","",1))
			local dups : list dups outcmnames				// And repeat while dups remain
		} //next while
		
	} //endif
	

	foreach v of local outcmnames  {
		capture confirm variable `v'
		if _rc==0	{										// If outcome name corresponds to var that already exists
			local badoutcm = "`badoutcm' `v'"				// Accumulate list of already existing `outcmnames'
		}
	}

	
	foreach obj  in  inputnames spfxlst outcmnames  {
		local obj = strtrim(stritrim("`obj'"))				// Strip leading and internal excess blank(s) from each local list
	}										

															// (NOTE DIFFERENCE BETWEEN OUTCMNAMES`nvl' AND UN-POSTFIXED VERSION)
	char define _dta[OUTCMNAMES] "`outcmnames'"				// There are as many`outcm/inputnames' as there are different outcome prfxs									
	char define _dta[INPUTNAMES] "`inputnames'"							
	char define _dta[PRFXNAMES] "`prfxvars'"				// ***********************************************************************
	char define _dta[VARLISTNO] "`varlistno'"				// Above chars re-arrange the per-varlist chars from before wrapper(3),
	char define _dta[STUBNAMES] "`stubnames'"				// so as to avoid having to discover empirically the number of values in
	char define _dta[OPTNAMES] "`optnames'"					// each dummy variable, as needed to be done in 'getoutcm(3) above'.
	char define _dta[SPFXLST] "`spfxlst'"					// Even more efficient access is now provided to 'gendummies' interim 
															// names, used in cleanup (0.1). But that global is only availabnle after
															// 'cmd'P for 'gendummies' has completed processing the data, so it would
															// not help us here or in getprfxdvars, below. Still, cleanup could be re-
															// written to gain clarity by basing itself on the earlier set of scalars.
															// ************************************************************************


	
	local skipcapture = "skip"								// If execution passes this point there were no coding errors above
	
		
*  *************	
//} //endcapture											// Close praces end codeblocks in which coding errors will be captured
*  *************

pause on
pause getoutcm(4+)
pause off
	
  if _rc & "`skipcapture'"==""  {							// If `skipcapture' is empty then a coding error was captured above
     errexit "Error in $errloc"
     exit 1
  }
	
  exit														// CLUGE AVOIDS "matching close brace not found" msg on errexit

  
  
  
end getoutcmnames



**************************************************************************************************************************************




capture program drop getoutcmnames							// Called from 'getprfxdvars' (next subprogram below this one)
															// (on return to which, local inputnames, outcmnames, spfxlst become chrstcs)

program define getoutcmnames, rclass						// Returns lists of input and corresponding outcome & strprfx names
															// (outcome names already fully prefixed; others combine to make outcm names)
															// TASKS FOR THIS PROGRAM ARE LISTED AT START OF CODEBLOCK 'getoutcm(2)'
															// *********************************************************************
pause getoutcm(1)
global errloc = "getoutcm(1)"

* ****************
//  capture noisily {										// Open braces enclose code within which any error will be captured
* ****************											// (and processed after the matching close braces at end of program)

    local cmd = "$cmd"										// Make local copy of $cmd global
	
	local inputnames  =  ""									// Local that will be returned to caller w list of inputnames
	local outcmnames  =  ""									// Ditto w list of outcome names
	local spfxlst = ""										// Ditto w list of full prefix that distinguishes outcome from input name
	local newpfx = ""										// By default the user has not optioned a deviation from default usage


															
															
	
	
											// (1) GET LIST OF PREFIX-NAMES FOR CURRENT `cmd' 
											//	   (`cmd' will generate 1 var for each optname)
											
												
	if "`cmd'"=="gendist"  local optnames     = "dprefix mprefix pprefix" 	   		   // (aprefx is implmntd just before codeblk 2)
	if "`cmd'"=="gendist" & "`proximities'"!=""  local optnames = "`optnames' xprefix" // Add xprefix if "proximities" were optd
	if "`cmd'"=="gendummies"  local optnames  = "duprefix"							   
	if "`cmd'"=="geniimpute" local optnames   = "iprefix mprefix"
	if "`cmd'"=="genmeanstats" local optnames = "nprefix meanprefix sdprefix minprefix maxprefix skewprefix kurtprefix sumprefix " ///
											  + "swprefix medianprefix modeprefix" 	   // (same order as in 'genyhatsP')
	if "`cmd'"=="genplace"  local optnames    = "iprefix mprefix pprefix" 
	if "`cmd'"=="genyhats" local optnames     = "bprefix" 	// `mprefix' will be substituted (below) if `multivariate' is optioned
															// Above are prefix-naming options that may be user-invoked for each cmd	
	
	
	
	
	
	
											// (1.1) GET IDENTIFYING CHARACTER(S) FOR CURRENT CMD (i.c. – eg "d" for gendist); prepare
											//		 `aprefix'
											
											
											
	local ic = substr("`cmd'",4,1)						    // Get initial char for vars, for most of them, is 4th char
															// (for 'genmeanstats' we substitute a list of stat-names)
	if "`cmd'"=="gendummies"  local ic = "du"				// (cmd genme also has non-standard `ic' but is processed differently)
															// This prefix ultimately eliminated in 'cleanup' (3), if not user-overwrttn
															// (so does 'genyhats', dealt with in next 'if `cmd'=="genyhats"' codeblk)
	
	
	
	
	
pause getoutcm(2)
global errloc = "getoutcm(2)"
		
		
											// (2) GET VARIABLES, PREFIXVARS, STUBNAMES AND STRING-PREFIXES FOR THIS VARLIST
											

											// ***************************************************************************************
											// Prefixes cumulate as variables are augmented with dummy-variables, distance measures,
											// imputed values, and y-hats – each command prepending additional prefixes to variable 
											// names. Every variable that is deemed an outcomes from each command will have a prefix
											// that records the provenance of that stackMe-generated variable. These prefixes should
											// not be changed without careful thought regarding alternative means for keeping track of
											// variable provenance (variable characteristics NOW PROVIDE A MEANS FOR DOING SO AND WE
											// HAVE PLANS FOR AN 'origin' UTILITY THAT WOULD PUT FULL PROVENNCE INTO OUTCM VAR LABELS)
											// ****************************************************************************************
											
											
	local statprfx : char _dta[STATPRFX]					// NOTE that 'genmeanstats' 'strprfx's were saved as charctrstcs at wrapper(3)
	local statlen = wordcount("`statprfx'")					// (only one varlist is allowed with 'genme' `cos never imagined more)
	local statrtrn : char _dta[STATRTRN]					// (same length as `statprfx')	
	local nvarlsts : char _dta[NVARLISTS]					// get N of varlists from characteristics NVARLSTS set in wrapper(2.1) 

	
	forvalues nvl = 1/`nvarlsts'  {							// Cycle thru all varlists (from scalar NVARLSTS)

	  local options : char _dta[OPTLIST`nvl']				// Retrieve `options' from data characteristic OPTLIST for this varlist
															//  user-chosen for this varlist with fully spelled-out optionnames)
	  if substr(strtrim("`options'"),1,1)==","  {
	  	local 0 = "`options'"								// Replay the user-supplied options-list
	  }
*	  		***********************
	  else  local 0 = ", `options'"							// (whether or not it starts with a comma)
*			***********************							// (lack of comma corrected here)

	  local mask : char _dta[MASK`nvl']
local show = "`mask'"
	  
*	  ******************	  
	  syntax [anything] [if] [in] [fw aw pw iw/], `mask'	// `upmask' is the culled mask with upper case 1st three char optnames
*	  ******************
	  
	  local apfx = "_"										// By default `apfx' contributes the final "_" to an outcomename
	  if "`aprefix'"!=""  {									// But if `aprefix' was user-optioned..
	    if substr("`aprefix'",-1,1)=="_"  local apfx = "`aprefix'" // If user put a "_" at end of optioned prefix then keep it
	    else  {												// (need this `else' format to avoid getting a final "__" instead of "_")
		  local apfx = "`aprefix'_"							// else add the trailing "_"
		}
	  } //endif												// (if `aprefix' was optioned with trailing "_", put all of it in `apfx')
	  
	  local varlist : char _dta[VARLISTS`nvl']				// FINAL SHOT AT TRANSFERRING THIS FLAG
	  local prfxvars : char _dta[PRFXVARS`nvl'] 			// Retrieve any prefixes that are varnames (THESE DO NOT AFFECT VARNAMES)
*	  local stubnames : char _dta[VARSTUBS`nvl']			// (imperative that option `stubnames' not be schlocked by empty scalar)
															// NOW IT IS SCHLOCKED BY EMPTY char; SO COMMENTED OUT
	  local strprfx : char _dta[PRFXSTRS`nvl']				// And any string prefix to those var prefixes (1 per listof `prfxvars')
	  if "`strprfx'"=="."  local strprfx = ""				// (so it is duplicated as many times in `strprfx' as there are outcomes)
	  
local show = "varlist: `varlist'; prfxvars: `prfxvars'; stubnames: `stubnames'"	  
	  
	  if "`cmd'"=="genyhats"  {
		local dvar = "`depvarname'"							// By default this is not a `multivariate' yhats command
	    local multivariate : char _dta[MULTIVARIATE`nvl']	// (there is no `bivariate option since that is the default')
		if "`multivariate'"!="" local dvar = "`depvarname'" // (`multivariate, if optd, means using the user-optd `depvarname'	– unless
															//  overruled by existence of a prefixvar (under v9 syntax, where it is
		if "`prfxvars'"!=""  {								//  the existence of a prefixvar that tells us yhat is multivariate)
		   local dvar = "`prfxvars'"						// Multivarite genyhats generates an m-prefixd depvar by default, trumped by
		   local multivariate = "multivariate"				//  `depvarname' opt or varlist-specfc prefixvar
		   local varlist = "`dvar'"							// If multivariate 'genyh' was opted or prfxd then `varlist' provides indeps
		   local optnames = "`mprefix'"						// (and default outcome – see above – has "m_" prfx or user-optd `mprefix')
		}
	  } //endif genyhats
	  
	  
	  
	  
	  
pause getoutcm(2.1)
global errloc = "getoutcm(2.1)"




	  
	  local nv = 0											// Variable # within varlist
	  
	  foreach v  of  local varlist  {						// Cycle thru all input vars for each varlist (inputs, for multiv genyh)
	  
		 local nv = `nv' + 1								// Increment position in varlist to synchronize w prfxvars & other lists
	   
		 foreach opt  of  local optnames  {					// Go thru optionable string prefixes for current cmd (usng v1 naming)
															// (`optnames' for each command were enumerated in getoutcm(0) – `cmd' will
															//   generate one outcome variable for each optname, appropriately prefixed
			local spfx = substr("`opt'",1,1)				// For most commands, interim vars generated by `cmd'P have this prefix
															// ('opnames' names are specific to the current command – see (1) above)																  
			if "`cmd'"=="gendummies"  {						// `cmd' gendummies gets multiple varnames from the values of each var
			   local spfx = "du"							// For 'gendu', interim prefix defaults to same as default outcome prefix
			   local name = "`v'"
			   local stubs : char _dta[VARSTUBS`nv']
			   if "`stubs'"!=""  local name = word("`stubs'",`nv')
			}												// (`spfx' will have been prefixed to (prhps already prefxd )`v' by `cmd'P)
			
			if "`cmd'"=="genmeanstats" {
			   local spfx = substr("`opt'",1,2)				// For 'genme' use 1st 2 chars of cmd's current optname as interim prefix
			   if "`opt'"=="medianprefix" local spfx = "md"	// "medianprefix" has same 1st 2 chars as "meanprefix"', so disambiguate
			   if "`opt'"=="meanprefix" local spfx = "mn"	// Ditto for 'meanprefix'
															// Poor design requires repeat of 'genmeanstats' parsing done at wrapper(3)
			   if "`spfx'"=="np"  local spfx = "n"			// Need this tweak to handle single character "n" option for 'genme'
															// (short for "n of observations – the "p" was next char of optn `nprefix')
			} //endif `cmd'=='genmeanstats'					// ('gendu' and 'genme' make no use of `ic', using `spfx' instead
			
			if "`cmd'"=="genyhats"  {
			   local spfx = "b" 							// cmd genyhatsP also assigns 2-char interim prfxs
			   if "`multivariate'"!="" local spfx = "m"		// `spfx' gets interim prefix generated by 'genyhats'
			   local opfx = "y`spfx'"						// Outcome var gets a "y" in front of that interim prefix
			}
															// (so interim vars may emerge from `cmd'P with two prefixes, merged below)
			if "`strprfx'"!="" local spfx = "`strprfx'"		// Overridden by `strprfx' prefix to stub/prfxvars list, if any
															// (LEGACY CODE MAY BE USED IF WE RESTORE USE OF PREFIXVARS)
			local opfx = "`spfx'"							// The outcm prefix is based on interim prefix, unless ``opt'' was optioned
															// (see "if ``opt''..", below)
			if strpos("gendist geniimpute genplace","`cmd'") { // For these three cmds, `opfx' gets a leading character from cmd name
				local opfx = substr("`cmd'",4,1) + "`opfx'" // (gendu genme genyh prefixes already have two chars; genst makes its own)
			}												// TWO CHAR INITIAL PREFIX IS HARD TO CODE IN 'getoutcm(3), SO COMMENT OUT? ***


			
								
	
	
	
pause getoutcm(3)
global errloc = "getoutcm(3)"


											// (3) BELOW CREATE AS MANY OUTCOME VARNAMES AS REQUIRED BY N OF OPTNAMES FOR THIS CMD
											//	   (OR BY N OF VALUES FOR EACH STUB IF OUTCOME IS A SET OF DUMMY VARIABLES)

															 // ***************************************************************************
															 // Here we manage the evolution of prefix initials as a variable progresses 
															 // through the succession of stackMe commands that constitute a stackMe work-
															 // flow. There will always be at least one and no more than two prefixes, un-
															 // less a user abrogates the process by optioning a user-defined prefix (which
															 // would thereafter remain unchanged unless by user). The first prefix will be
															 // a two-char prefix constructed from the single-character cmd-specfic interim 
															 // prefix set by the current cmd's `cmd'P program, along with the current com-
															 // mand's `ic' (initl char) added by 'cleanup' accordng to a renaming template 
															 // established here in the current codeblock. The second prefix will cumulate a 
															 // record of previous stackMe commands that have shaped the variable concerned, 
															 // one character per command (generally the first of the two characters in the 
															 // previous first prefix (but, for genyhats, the second prefix ("b" or "m")). 
															 // So, with each stackMe command that is executed, the previous prefix's first 
															 // char becomes the first char of the second prefix and the replacement first 
															 // prefix becomes the two-characters defining the latest outcome var's status.
															 // Note that `gendummies' & `genmeanstats' don't contrbute to a var's history.
															 //    AT THIS POINT IN EXECUTION OF THE CURRENT COMMAND, `cmd'P has not yet put 
															 // a new prefix on the front of `v', which is still what the user typed. WHAT 
															 // WE DO HERE IS ANTICIPATE NAME CHANGES that will be made by `cleanup' so we  
															 // can see if fully prefixed variable names implied by user choices (and saved
															 // in codeblk getoutcm(3.1) below for use in `cleanup') are valid. Determining
															 // the validity of anticipated varnames is the task of codeblk getoutcm(4)).
															 // *****************************************************************************


		  local X = 0										// Logical switch specifies that a codeblk will NOT be executed for each `v'
		  local true = 1									// (based on whether their prefixes provide a historical workflow record)
		  local Y =  `true'									// Logical switch specifies that a prefix is expected			 		  
		  local false = 0									// (based on whether we already found the right `oname')
						
		  if "`cmd'"=="gendist" & strpos("d x","`spfx'")  local X =`true'	// If outcome is a primary one for 'gendist' do this codeblk
		  if "`cmd'"=="genyhats" & strpos("b m","`spfx'")  local X =`true'	// If outcome is a primry one for 'genyhats' do this codeblk
		  if "`cmd'"=="geniimpute" & strpos("i m","`spfx'") local X =`true' // If outcome is a primary one for 'geniimpute' ditto
		  if "`cmd'"=="genplace"  local X =`true'			 				// RETHINK THIS CODING DURING genplace PROG DEVELOPMENT		***
															// `spfx' is prefix generated by `cmd'P; other prefixes are not historic
															
															
*		  ********
		  if  `X'  {										// If we have the prefix string for a primary outcome variable.. 
*		  ********										    // (other prefixes are "p","m" for gendi; "m" for genii)



			local cumulate : char `v'[cumulate]				// Retrieve cumulation history (tells whether to cumulate workflow record)
															// (NOTE that this characteristic is associated with the input varname)
			if "`cumulate'"=="no"  local cumulate = ""		// Recast "yes"/"no" flag as present/empty flag (accessed at start of 3.1 )
			else  {											// (user can only indicate "no" by defining 'char _varname[cumulate] no')
			  if "`cumulate'"==""  local cumulate = "yes"   // By default will cumulate workflow history (char initially returns empty)
			}												// (cumulation is actually performed in cleanup(3), when interim vars exist)
			local oname = "`opfx'`apfx'`v'"					// For all stackMe cmds except for genstacks, the 1st prefix was set above
															// (if `cumulate' is not empty or "yes"/"no" it contains list of past cmds)

															 // **************************************************************************
															 // Local `outcmname's `ic' is `cmd-specific' prefix set by `cmd'P (if `v' has
															 // any prefixes they were put there by previous `cmd'Ps). If there are two of
															 // them the 2nd is the cumulatng prefix that will be aquiring earlier `ic's.
															 // **************************************************************************

			if "``opt''"!=""  {								 // If this optname, specific to each `cmd', was user-optioned...
															 // (signalled by non-empty ``opt'', which points to what was optioned)
			  local opfx = "``opt''"						 // Use double-quotes to access the string that the user typed
															 // (this string will replace the default `ic' prefixing an outcome varname)	
			  if substr("`opfx'",-1,1)=="_"  local opfx = substr("`opfx'",1,strlen("`opfx'")-1) 	// Remove trailing "_" if any
															 // (would duplicate the "_" provided by a default `aprefix')				
			  local cumulate = "no"							 // And set flag to indicate a user-initiated change in prefix (done below)
			} //endif ```opt'''								 // (which we will address when we have parsed the rest of the prefix	
			
			local add = ""									// By default there is as yet no prefix
			  
			local opfx = "`ic'`spfx'"						// For most commands we simply add `ic' to front of interim prefix
															// (put there by `cmd'P)
			if strpos("gendummies genmeanstats","`cmd'") {  // But for these `cmds'..
			  local newpfx = `spfx'							// We use the two-char prefix already created as interim prefix by `cmd'P
			}
			
			if "`cumulate'"!="no"  	{						// If cumulation was not terminated by user-specified outcome prefix..
												
			  gettoken frst rest : v, parse("_")			// If input has no "_" then `rest' stays empty; else gets a "_..." string 
			  if "`rest'"!=""  {							// If `v' was prefixd, we will include that prefix in `oname'(see below)
			    local rest = substr("`rest'",2,.)			// Trim the leading "_" from `rest'
				local add = substr("`frst'",1,1)			// And put into `add' the 1st character of the 2-char 1st prefix
															// (`add' will be prepended to cumulating prefix(es) preceeding 2nd "_")
			    if "`cmd'"=="gendummies"  { 				// Unless `cmd' is 'gendummies' (see below for 'genmeanstats')
			      local add = substr("`frst'",2,1) 			// (when we keep 2nd char (overwriting the 1st char, put there just above)										  
			    }
				if "`cmd'"=="genmeanstats"  local opfx = "`frst'"
*				else  {										// For 'genmeanstats' retain all of first prefix
*				  local opfx = "`ic'`add'"					// For other commands, prefix selected prefix char with `ic'
*				}											// (providing `opfx' with the 2-char prefix that is 1st prefx on all outcms)
			    if strpos(substr("`rest'",2,.),"_")  {  	// If there is ANOTHER "_" after first one.. (look beyond 1st "_" of `rest')
			      local rest = substr("`rest'",2,.)			// Strip off leading "_", parsed on far above and still at front of `rest'
				  gettoken cum rest : rest, parse("_")		// And put into `cum' the cumulating prefix that is 2nd prefix, if any
				  local rest = substr("`rest'",2,.)			// 2nd "_" will come from `apfx', which always ends with "_"
			    }											// (if `rest' had no 2nd "_")
			    local oname = "`opfx'_`add'`apfx'`rest'" 	// MONEY LINE, WHERE A PFX FROM PREVIOUS CMD IS ABSORBD INTO CUMULATNG PRFX
			  }												// (but that concatenation holds good only if `v' has a second prefix)
local show = "opfx `opfx'; add `add'; apfx `apfx'; rest `rest'"
			  else  {										// Else `rest' is empty, so not a first (or any) prefix; look no further
															// (but we still must deal with `cumulate' so we need Y to prevent overwritng)
			    local Y = `false'						 	// (we now have established an `oname' for the case where there was no prefix)
			    gettoken nxtpfx Zndrest : rest, parse("_")	// `nxtpfx' would be second prefix in front of `v', the current varname
			    if `Y'&"`Zndrest'"=="" loc oname="`opfx'`apfx'`rest'" // If there's NO 2nd prefix, `oname' needs `opfx_' before `rest'
local Zndrest = "nxtpfx `nxtpfx'; Zndrest `Zndrest'; oname `oname'"															// (this overwrites the `oname' from 'MONEY LINE')
			    if "`newpfx'"!=""  {						// (so `oname' stays unchangd as we deal with any user-optnd prefix change)
				  if "`cumulate'"!=""  {					// If `cumulate' flag is NOT empty, this is a change from previous default
															// But a change TO keepng workflow history isn't allowed
				    if `limitdiag'!=0  {					// (if displayng diagnostics give warning then continue with next var, `v')
				      dispLine "WARNING: Cannot change TO keeping prefx record of wrkflow history; use utility {help SMorigin:{ul:SMori}gin}" ///
							  aserr
				      if `Y' local oname = "`newpfx'"		// `newpfx' was established before 'if "`cumulate'"!="no"', above
				    } //endif `limitdiag'	
				  } //endif `cumulate'
				} //endif `newpfx'							// `newpfx' must be empty; so user did not option a different prefix string
			  
			  } //endelse `Istrest'							// And 2nd rest of `v' (`Zndrest') is NOT empty so is a cumulating prefix
															// (which is what we needed to confirm)
			} //endif `cumulate'
			
		  }	//endif `X'										// End of codeblk executd only for vars that keep a prfx-str wrkflow record
		  

		  else  {										 	// Outcome vars without workflow record still get an identifyng prefx
		  	 local oname = "`opfx'`apfx'`v'"				// (currently same coding as for vars w'out extant prefixes, far above)
		  }

		  
		  
		  
			
			
pause getoutcm(3.1)
global errloc = "getoutcm(3.1)"

											// (3.1) HERE WE BUILD THE LISTS OF INPUT, OUTCOME AND PREFIX ITEMS THAT WILL GOVERN
											//		 THE PREFIX-BUILDING THAT DETERMINES CHANGES TO VARIABLE NAMES AS VARIABLES
											//		 ARE GIVEN INTERIM PREFIXES BY `cmd'P AND THEN OUTCOME NAMES BY 'cleanup'
		
		  
			if strpos("gendist geniimpute","`cmd'")	{	 	  // For these commands stick `ic' character on front of `oname' prefix
			   local oname = "`oname'"						  // DK WHAT THIS IS FORMAT													***
*			   local oname = "`ic'`oname'"					  // (already done, at top of codeblk(3), for genyh) so
			}												  

			if ! strpos("gendummies genmeanstats","`cmd'") {   // ******************** 		 // If `cmd' is NOT 'gendu' or 'genme'..
*			  												   // IN THE GENERAL CASE, store `outcmnames', etc., for r-return to caller
															   // ********************
															   
															   // THE N OF OUTCOME VARS IS ONE PER OPTION, NO MATTER WHETHER USER-OPTD
				****************   *****************		   // Use input prefix (from start of `opt' loop) for `v'
				local inputnames = "`inputnames' `v'"		   // May already have a prefx, if var has already been procssd by stackMe cmd
				local spfxlst = "`spfxlst' `spfx'"		 	   // Provides prefix for `cmd'P-genratd interm (prhps already prfxd) varname
				local outcmnames = "`outcmnames' `oname'" 	   // 'opfx' is `spfx', unless overriden; `spfx' is interiim `cmd'P prefix
				local varlistno = "`varlistno' `nvl'"		   // Links outcome var to its origin in the varlist typed by user
*				****************   *****************		   // For most commands the `opfx' starts with `ic' unless overridden	
															   // (if aprefix was not optnd, outcome prefix is "`ic'_" – see above)
		    } //endif										   // (`oname' already contains `aprefix' (aka `apfx'), if optioned)

			
															 // **************************
															 // IF COMMAND IS 'gendummies' (can have several values == several outcomes)
			if "`cmd'"=="gendummies"  {						 // **************************

				local name = "`v'"							 // FOR 'gendu', N OF OUTCOME VARS IS ONE FOR EACH VALUE OF EACH INPUT VAR
															 // (`name' needed to provide for stubs either derivd from input or optiond)
*				if "`stubname'"!="" local name="`stubname'"  // Optiond stubname replaces default stubname (derived from input varname)
															 // COMMENTD OUT AS VERSN 10 PUTS OPTD STUBNAMES INTO CHAR IN wrapper(2.1)
				if "`stubnames'"!=""  {						 // If prefix `stubnames' not empty they take priority over optiond stubname
				  local name = word("`stubnames'",`nv')	 	 // Trumped by a stubname corresponding to each input variable
				}											 // (using `name' in lieu of `v' avoids possibilty of schlocking `v')
				local tlen = strlen("`name'")				 // Get length of varname pointed to by `v' or `stubname'
															 // NOTE DIFFERENCE BETWEEN SINGULAR 'stubname' AND PLURAL 'stubnames' ABOVE
				if real(substr("`name'",`tlen'-1,1))!=. { 	 // If last char of `name' is numeric (conversion to real is NOT missng)..
				   errexit "Apparent user error: a dummy input stub should NOT end with a numeric character"
				   exit 1
				} //endif
				if "`noduprefix'"!="" local spfx="`duprefix'" // (overridden if `duprefix' was user-optioned)
															// Save in list of varname prefixes used to diagnose varname conflicts
				quietly levelsof `v', local(V)				// MUST GET VALUES OF VARIABLE, NOT STUB!		  
				foreach val of local V  {				   	// For gendu we get as many outcome names as the var had values
															// (there is only one quasi-optname for gendummies)
				   capture confirm number `val' 			// Error if `val' is NOT numeric 
				   if _rc {
			          errexit "Apparent user error: a dummy outcome varname should have numeric values"
			          exit 1
				   }
				   ************************   ************	// HERE N OF OUTCOME VARS IS ONE FOR EACH VALUE OF EACH INPUT VAR
				   local inputnames = "`inputnames' `v'" 	// `inputnames' gets  varname that user typed, as many times there are values
				   local spfxlst = "`spfxlst' `spfx'"		// Always missing for gendummies SO WE DON'T USE `ipfx'
				   local outcmnames = "`outcmnames' `opfx'`apfx'`name'`val'" // 'opfx' is "du" unless overridden
				   local varlistno = "`varlistno' `nvl'"	// Links outcome var to its origin in the varlist typed by user
*				   ************************   ***********	// (`name' is unique to 'gendu', allowing `name'`val' to replace `oname')
															// (also, as with 'genme', we don't cumulate dummy variable prefixes )

				} //next `val'
				
			} //endif "`cmd'"=="gendummies"					// END OF PROCESSING FOR COMMAND 'gendummies'
			  
			  
			  
															// ****************************
			if "`cmd'"=="genmeanstats"  {					// ELSE COMMAND IS 'genmeanstats' (can have several optnames )
															// ****************************	  (we are already in optname loop)
															
															// NOTE THAT 'genmeanstats' PREFIXES, ESTABLISHED BY OPTION 'stats'
															// AFTER 'wrapper'(3), DETERMINE WHICH `optnames', CURRENTLY BEING
															// CYCLED THRU & IDENTIFIED BY `spfx', WILL GOVERN THE OPTIONAL
															// RENAMING OF THE 'genmeanstats' OUTCOME VAR BY CHANGING ITS PREFIX.
															// ******************************************************************
				if strpos("`statprfx'","`spfx'")==0 continue // Continue with next option if this one not in list of optd stats
															// (`statprfx' was established at wrapper(3) & passed in char _dta[STATPRFX])
				
				****************   ******************		 // HERE THE NUMBER OF OUTCOME VARS IS THE NUMBER OF OPTIONED STATS
				local inputnames = "`inputnames' `v1'"		 // Caller may need unadorned input varname
				local spfxlst = "`spfxlst' `spfx'"			 // 'genmeanstats' uses `stat' as prefix for `cmd'P interim names
				local outcmnames = "`outcmnames' `spfx'`apfx'`v'"  // There is no `opfx' for 'genme'; instead we use `spfx' again
				local varlistno = "`varlistno' `nvl'"		 // Links outcome var to its origin in the varlist typed by user	
*				****************   ******************		 // Note that we do not cumulate genme prefixes
													

			} //endif `cmd'=="genmeanstats"				 // END OF PROCESSING FOR COMMAND 'genmeanstats'
			 
			local spfx = ""								 // Empty this in case next var has no user-optioned prefix

		  } //next `opt'
		  
	   } //next 'v'
	  
	  
	} //next 'nvl'
	

	
	
	
	
*pause on
pause getoutcm(4)
global errloc = "getoutcm(4)"
pause off	
	
											// (4) CHECK FOR DUPLICATE OUTCOME NAMES AND DROP IF USER PERMITS
											
// IN PRACTICE, FOR UNKNOWN REASONS, ALL OUTCOME NAMES ARE DUPLICATED -- FIND OUT WHY OR USE THIS CODE AS CLUGE TO ELIMINATE DUPS		***
											
											
												
	local dups : list dups outcmnames						// 'list dups' returns list of outcome names that are duplicates
															// (see below for check of whether outcome name duplicates existing name)
	if "`dups'"!=""  {

// HERE IS CLUGE OMITTING REPORT OF DUPLICATE OUTCOME NAMES BY COMMENTING OUT NEXT SIX LINES											***
/*
		dispLine "You have specified duplicate outcome names: `dups'; drop excess names?"
*				  12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		local rmsg = r(msg)
		capture window stopbox rusure "`rmsg'"
		if _rc  {
			errexit "Lacking permission to drop duplicate outcome varnames, will exit on OK"
			exit 0
		}													// Else drop these dups one-at-a time, first to last
*/
		while wordcount("`dups'")>0  {						// While there are any duplicates
			local isdup = word("`dups'",1)					// Drop one copy of first duplicate name (substitute "" for it)
			local outcmnames = stritrim(subinstr("`outcmnames'","`isdup'","",1))
			local dups : list dups outcmnames				// And repeat while dups remain
		} //next while
		
	} //endif
	

	foreach v of local outcmnames  {
		capture confirm variable `v'
		if _rc==0	{										// If outcome name corresponds to var that already exists
			local badoutcm = "`badoutcm' `v'"				// Accumulate list of already existing `outcmnames'
		}
	}

	
	foreach obj  in  inputnames spfxlst outcmnames  {
		local obj = strtrim(stritrim("`obj'"))				// Strip leading and internal excess blank(s) from each local list
	}										

															// (NOTE DIFFERENCE BETWEEN OUTCMNAMES`nvl' AND UN-POSTFIXED VERSION)
	char define _dta[OUTCMNAMES] "`outcmnames'"				// There are as many`outcm/inputnames' as there are different outcome prfxs									
	char define _dta[INPUTNAMES] "`inputnames'"							
	char define _dta[PRFXNAMES] "`prfxvars'"				// ***********************************************************************
	char define _dta[VARLISTNO] "`varlistno'"				// Above chars re-arrange the per-varlist chars from before wrapper(3),
	char define _dta[STUBNAMES] "`stubnames'"				// so as to avoid having to discover empirically the number of values in
	char define _dta[OPTNAMES] "`optnames'"					// each dummy variable, as needed to be done in 'getoutcm(3) above'.
	char define _dta[SPFXLST] "`spfxlst'"					// Even more efficient access is now provided to 'gendummies' interim 
															// names, used in cleanup (0.1). But that global is only availabnle after
															// 'cmd'P for 'gendummies' has completed processing the data, so it would
															// not help us here or in getprfxdvars, below. Still, cleanup could be re-
															// written to gain clarity by basing itself on the earlier set of scalars.
															// ************************************************************************


	
	local skipcapture = "skip"								// If execution passes this point there were no coding errors above
	
		
*  *************	
//} //endcapture											// Close praces end codeblocks in which coding errors will be captured
*  *************

pause on
pause getoutcm(4+)
pause off
	
  if _rc & "`skipcapture'"==""  {							// If `skipcapture' is empty then a coding error was captured above
     errexit "Error in $errloc"
     exit 1
  }
	
  exit														// CLUGE AVOIDS "matching close brace not found" msg on errexit

  
  
  
end getoutcmnames




**************************************************************************************************************************************




capture program drop getprfxdvars							// Called from wrapper(5) with `options' options-list


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
											// COPY CONFLICED OUTCOME TO A TEMPVAR AND ACCUMULATE LIST OF SUCH TEMPORARY CHANGES 
											// IN GLOBAL namechange – A GLOBAL THAT GOVERNS RESTORATION OF ORIGINAL NAMES AFTER NEW 
											// OUTCOME ivars IN WORKING DATA HAVE BEEN RENAMED IN 'cleanup' TO ovars (renamed to local 
											// namechange in 'cleanup).
											// VOCABULARY: `iname'/`oname' are text strings and ivar/ovar are vars with those names
											//			   [`cmd'P-generated] `ivar' is renamed to `ovar' by 'cleanup' before cmd exit
											//****************************************************************************************

pause getprfxdv(0)
global errloc "getprfxdv(0)"

											// (0) SET UP CONSTANTS NEEDED BY LATER CODEBLOCKS


* *****************											
//  capture noisily {										// Syntax (etc) errors in captured codeblks to up to matching close  
* *****************											//   brace will cause jump to command following that close brace
		
	local ic = substr("`cmd'",4,1)							// `ic' (for identirying char(s)) is used to prefix `cmd'P-generated vars
	if "`cmd'"=="genmeanstats" | "`cmd'"=="gendummies" {	// 		(copied from $ic at start of program, above)
	   local ic = substr("`cmd'",4,2)
	}														// One identifying char in general but two chars for gendu and genme
															// ('gendu' will ultimaately have its prefix removed, if not user-updated)
															// ("_" is ultimately appended) if not contained in user-optd `aprefix')
															// COMMENTED OUT AS DUPLICATNG CODE IN 'getoutcmnames'
	
*	*************											// Subprog gets lists of inputs, outcomes to convert to charcrstcs below
    getoutcmnames 											// `getoutcmnames' replays the original commandline							
	if "$SMreport"!=""  exit 1								// If returning from errexit, exit to next level up
*	*************											// 'getoutcmnames' HAS 'IRONED OUT' VARIABLE TYPES AND VARIABLE LISTS
															// (whatever their origin, any var to be newly created gets equal status)

															// VALUES HELD AS CHARACTERISTICS NOW MUST BE ACCESSED AS LOCALS
	local outcmnames : char _dta[OUTCMNAMES]				// There are as many`outcmnames' as there are different outcome prfxs
	local inputnames : char _dta[INPUTNAMES]				// There are as many`inputnames' as there are different outcome prfxs
	local prfxvars : char _dta[PRFXNAMES]					// Ditto (CALLING THEM prfxvars IS UNFORTUNATE LEGACY NAMING CHOICE)		***
	local varlistno : char _dta[VARLISTNO]					// There are as many `varlistnos' as there were varlists
	local stubnames : char _dta[STUBNAMES]					// Same for the `gendummies' `stubnames' if STUBNAMES is not missing
	local optnames : char _dta[OPTNAMES]					// Save having to initialize these again for this subprogram
	local spfxlst : char _dta[SPFXLST]						// ('genme' has the same multiplier in regard to stat names in $statlst)
															// (EACH CHARACTERSTC IS EITHER NAME/STRING/# OR MISSING, CODED AS A PERIOD)	
	

	local rename = ""										// List of vars to be temporarly renamed until user ops are implementd
															// (at end of 'cleanup', which is final subprogram called by wrapper)	
	global namechange = ""									// Will hold list of varnames temporarily changed to avoid name conflicts

	
	


pause getprfxdv(1)
global errloc "getprfxdv(1)"
	   
											// (1)	 DROP ANY VARS TEMPORARILY RENAMED, WITH "___" INITIAL PREFIXE (AND
											// 		 APPARENTLY REMAINING IN DATASET DUE TO UNTIMELY ERROR EXIT) THAT NEED TO BE
											//		 DROPPED SO AS TO AVOID NAMING CONFLICTS WITH NEWLY GENERATED U.C. PREFIXED
 											//		 VARS. THIS CODEBLOCK MUST COME FIRST SO AS TO AVOID CONFUSION WITH VARIABLES
											//		 WHOSE FIRST PREFIX CARACTER IS NEWLY MADE TEMPORARY
											

	

	local nnames = wordcount("`outcmnames'")
	  
	
	if substr("`oname'",1,3)=="___"  drop ___* 			// If any ___* vars are hanging around after error exit, drop all of them	
														// ("___" PREFIX IS PROGRAM-ASSIGNED NOT USER-DEFINED; DK WHY IGNORED THIS)	***
	
	
	
	
	
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
	   if "`cmd'"=="gendummies"  {
	     local sname = word("`stubnames'",`i')				// This local returned from 'getoutcmnames' where retrieved in codeblk(0)
	     if "`sname'"!="."&"`sname'"!="" local temp="`sname'" // If that word is NOT coded missing ("."), replace `temp' with it
	   }													// (gives us the 'gendummies' outcome stub, if `cmd' is 'gendummies')
	   else local sname = ""								// We are cycling thru these four lists (matched on outcome variable name)
	   
	   capture confirm variable `oname'
	   if _rc==0  local badonames = "`badonames' `oname'"	// If `oname exists' add to list of vars to be dropped (w user permission)
															// (two identical outcomenames cannot coexist)
															
	   capture confirm variable `pf'_`temp'					// (temp is 'iname' or, if 'gendu', maybe stubnm; so `pf'_`temp' is interim)
	   if _rc==0  local rename = "`rename' `pf'_`temp'"		// Same for `cmd'P-generated interim variable
															// (these will not coexist after interims have been renamed in 'cleanup')
	} //next `i'->oname
	

	
	
	if "`rename'"!=""  {									// If `rename' is not empty..
		
		foreach name of local rename  {						// Cycle thru all names in list

*			**********************
			rename `name' ___`name'							// THIS IS THE MONEY COMMAND WHERE PRECAUTIONARY RENAMING IS DONE
*			**********************							// (three-"_" prefx chars are used to distingsh from standrd Stata tempnmes)

			global namechange = "$namechange ___`name'"		// Add the new name to global list of vars needing previous names restored															// (this will be done as final task of subprogram 'cleanup')

		} //next `name'
															// (it is the possible exit before doing this that calls for cdblk 1 above)
	} //endif `rename'
	
	char define _dta[NAMECHANGE] "$namechange"				// Save global in same-named scalar to protect against 'preserve'/`restore'
															// (apparent source of content-loss for globals)
	
	
		
	if "`badonames'"!=""  {									// If we found name conflicts for outcmnames in code above..
															// (distinguished because they call for a specific error message)	
		dispLine "(Possibly prefixed) outcome names already exist: `badonames'; drop them & continue – ok?" "aserr"
*				   12345678901234567890123456789012345678901234567890123456789012345678901234567890 
															// (name conflict could be with prefixed or unprefixed existing var)
		local rmsg = r(msg)									// `rmsg' is returned pre-formatted for stopbox rusure or stop	
		capture window stopbox rusure "`rmsg'"
		if _rc  {											// If user did not respond with 'ok'
			errexit, msg(Lacking permission to drop listed vars, will exit on 'ok')
			exit 1
		}
	   
		else  {												// Else drop these variables
		  foreach var of local badonames  {
			capture drop `var'
		  }
		} //endelse							
		
	} //endif badonemes
	
									
	
	local skipcapture = "skip"								// Flag to skip the endcapture block if entered it from here
	

	
* **************	
//  } //endcapture											
* **************

pause getprfxdv(skip)

pause off
 
  if _rc & "`skipcapture'"==""  {
   	 errexit "Error in $errloc"
     exit _rc
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
			exit 1
		  }
		  
		} //endif 'wtexp'
		
		return local wtvars `keepv'
		
		local skipcapture = "skip"

*	**************
	} //endcapture
*	**************
	
    if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit 1
    }
														
	

end getwtvars



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
			exit 1
		  }
		  
		} //endif 'wtexp'
		
		return local wtvars `keepv'
		
		local skipcapture = "skip"

*	**************
	} //endcapture
*	**************
	
    if _rc & "`skipcapture'"==""  {
   	  errexit "Error in $errloc"
      exit 1
    }
														
	

end getwtvars



********************************************************************************************************************************



capture program drop isnewvar								// NO LONGER CALLED from getprfxdvars 										***


program isnewvar											

version 9.0


  global errloc "isnewvar"
  
  local prfxdnames : char _dta[PRFXDNAMES]
  
  local newprfxdnames = ""
	
	
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
	      local prfxdnames = "`prfxdnames' `var'"			// Add to global list final names of outcome vars
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
      exit 1
   }
														
  
	
end //isnewvar



********************************************************************************************************************************



capture program drop isnewvar								// NO LONGER CALLED from getprfxdvars 										***


program isnewvar											

version 9.0


  global errloc "isnewvar"
  
  local prfxdnames : char _dta[PRFXDNAMES]
  
  local newprfxdnames = ""
	
	
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
	      local prfxdnames = "`prfxdnames' `var'"			// Add to global list final names of outcome vars
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
      exit 1
   }
														
  
	
end //isnewvar



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
	   if "$SMreport"!="" exit 1								// See if error was reported by program called above
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
	   
*	   ******************	   
	   local 0 = "`vars'"										// Pretend user typed only one varlist; put back in '0'
*	   ******************

*	   **************************
	   syntax namelist(name=keep)								// Put names into local 'keep'
*	   **************************

	   local stlist = ""										// Stublist derived from this one varlist
	
	   while "`keep'"!=""  {
		  gettoken s keep : keep								// 's' is each word in 'keep', one at a time
		  while real(substr("`s'",-1,1))<.  {					// While last char is numeric
			local s = substr("`s'",1,strlen("`s'")-1)  			// Shorten `s' by one trailing numeral
		  }														// Exit while with `s' shorn of numeric suffix
		  if "`s'"!= word("`stlist'",-1)  {						// If this stub is not the same as previous one..
		     local stlist = "`stlist' `s'"						// Append it to `stlist'
		  }					
	   } //next `keep'											// (and cumulating across successive varlists)
	  				  
	   if wordcount("`stlist'")>1  {
			errexit "Variables in battery do not all have same stub: `stlist'"
			exit 1
	   }			  
	   local stub = "`stlist'"									// Holds the unique stub from stlist
	   
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




capture program drop showdiag1								// Called from wrapper(6) to set up for diagnostic displays if optioned

program define showdiag1									// Prepares to display diagnostics and extra diagnostics if optioned


global errloc "showdiag1"


*	*****************
//	capture noisily {
*	*****************


		args limitdiag c nc nvarlst
		
		if "$cmd"=="genstacks" {									  // For cmd genstacks we by-pass normal sources for vartest
*			if `nvarlst'==0  local nvarlst = 1
			local vartest : char _dta[MULTIVARLST]						
		}
local show = "`vartest'"			
		
		local nvarlst : char _dta[NVARLISTS]
		
		forvalues nvl = 1/`nvarlst'  {								  // Cycle thru list of varlists for this command

			if "$cmd"!="genstacks"  {								  // If this is not a genstacks command
				   local varlist : char _dta[VARLISTS`nvl']
			}
			
			else  {													   // Else this is a genstacks command
				local varlist : char _dta[GENSTKVARS]
			}
			
			local vartest = subinstr("`varlist'",".","",.)	  // Remove any missing-symbols (DK where they come from)
			unab vartest : `vartest'

			
			local test : list uniq vartest					  // Strip any duplicates of vars in vartest; put result in 'test'
			local nvars = wordcount("`test'")
			scalar minN = .									  // (a big positive number)
			scalar maxN = -999999							  // (a bug negative number)

			local noobsvarlst = ""							  // global will hold list of vars with no obs in this context
				   
			foreach var  of  local test  {					  // For each var in 'vartest' (now 'test')
						
					tempvar misvar count						  // Create temporary vars to count N of missing
					qui gen `misvar' = missing(`var')			  // Code mis'var' =0, or =1 if missing
					qui capture count if ! `misvar'				  // Unless error, yields r(N)==0 if var does not exist
					local rN = r(N)
					local rc = _rc								  // Place command in left margin because of how it prints
				    if `rc' & `rc'!=2000  {						  // If non-zero return code which is not 'no obs'
*						              12345678901234567890123456789012345678901234567890123456789012345678901234567890 
						errexit "Stata program error `rc' at $errloc – click blue return code for details") "`rc'"
						exit 1
					}
					if `rN'==0  {								  // If there are no non-miss obs for this var in this context
						local noobsvarlst = "`noobsvarlst' `var'"  // Store any vars with no obs 
					}
					else {										  // Else, if vars were not flagged as all-missing
						if `rN'<minN  scalar minN = `rN'		  	  // Update _N min and max scalar values for max & min Ns
						if `rN'>maxN  scalar maxN = `rN'			  // Scalars can be accessed from showdiag2
					}
					quietly capture drop `misvar' 				  // Drop these two vars
					quietly capture drop `count'
						
			} //next var
		
		} //next 'nvl'
		
		
		char define _dta[NOOBSVARLST] "`noobsvarlst'"		
				
		if !_rc  {								  		  		// Only execute this codeblk if an error has not called for exit 
			if `rc'!=0 & `rc'!=2000 {						  	// If there was a different error in any 'count' command...
				errexit "Stata error `rc' at $errloc in contxt `lbl' – click on return code for details" // LBL IS A SCALAR; 'lbl' a local
*						 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
				exit `rc'									  	// Set flag for wrapper to exit after restoring origdata
			}
				   
		} //endif !_rc
					
		local skipcapture = "skip"

		
*	**************
//	} //endcapture
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
		
		local noobsvarlst : char _dta[NOOBSVARLST]
			
		local limitdiag : char _dta[LIMITDIAG]					  	  // Retrieve user-optioned diagnostics control code
		
			
			if `nc'>1  local multiCntxt = 1							  // Different text for each context than whole dataset
			else local multiCntxt = 0
	
			local numobs = _N										  // Here collect diagnostics for each context 
				   					  
			if `limitdiag' >=`c' & "$cmd'="!="geniimpute" {			  // `c' is updated for each different stack & context
																	  // 'geniimpute' prints its own diagnostics
				local lbl = LBL										  // Below we expand what will be displayed
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
				  noisily display _newline "`msg'"					 // Noisily display the msg

				    if "`xtra'"!=""  {
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
						} //endif `nwrds'
					  } //endif $noopsvarlst
					} //endif `xtra'
					} //endif "`xtra'"
					  
					local minN = minN							 	 // Make local copy of scalar minN (set in showdiag1)
					local maxN = maxN								 // Ditto for maxN
*					local lbl : label lname `c'
					local lbl = LBL								 // THE UPPR CASE lbl IS A SCALAR THAT KEEPS ITS VALUE ACROSS PROGRAMS			***
					local newline = "_newline"
					if "$cmd"=="genstacks" local newline = ""
					  
					if `multiCntxt'  noisily display 				/// geniimpute displays its own diags
						 "`other'in context `lbl' have between `minN' and `maxN' valid obs"						 
*					  noisily display "{txt}" _continue
				
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
	   if "$SMreport"!="" exit 1								// See if error was reported by program called above
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
	   
*	   ******************	   
	   local 0 = "`vars'"										// Pretend user typed only one varlist; put back in '0'
*	   ******************

*	   **************************
	   syntax namelist(name=keep)								// Put names into local 'keep'
*	   **************************

	   local stlist = ""										// Stublist derived from this one varlist
	
	   while "`keep'"!=""  {
		  gettoken s keep : keep								// 's' is each word in 'keep', one at a time
		  while real(substr("`s'",-1,1))<.  {					// While last char is numeric
			local s = substr("`s'",1,strlen("`s'")-1)  			// Shorten `s' by one trailing numeral
		  }														// Exit while with `s' shorn of numeric suffix
		  if "`s'"!= word("`stlist'",-1)  {						// If this stub is not the same as previous one..
		     local stlist = "`stlist' `s'"						// Append it to `stlist'
		  }					
	   } //next `keep'											// (and cumulating across successive varlists)
	  				  
	   if wordcount("`stlist'")>1  {
			errexit "Variables in battery do not all have same stub: `stlist'"
			exit 1
	   }			  
	   local stub = "`stlist'"									// Holds the unique stub from stlist
	   
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



capture program drop varsImpliedByStubs

program define varsImpliedByStubs, rclass		// Subprogram converts list of variable stubnames to a list of vars implied 
												// (eliminating false positives with longer stubs)
global errloc "varsImpl"


* ****************
  capture noisily {
* ****************
												

	local true = 1												// By default we expect command followed by list of stubnames
	local isStub = 1											// Set up logical requirements for test that follows
	
	local maybevar = word("`0'",1)								// Get first word following command-name in string typed by user

/*	capture confirm variable `maybevar', exact					// 'exact' option ensures abbreviations dont count
*/																// APPARENTLY NOT !
	if real(substr("`maybevar'",-1,1))>=. local isStub = `true' // If supposed stub has no numeric suffix (convert to real failed)
	else  {
	   errexit "Program error 'varsImpliedByStubs' expects a stublist"
	   exit 1
	}															// Else, given 'stackMe' syntax rules, we should have a stub

*	**************************																
	syntax namelist(name=keep)									// Put stubs into `keep'
*	**************************	
	
	local varlist = ""											// Accumulating list of vars implied by each stub in turn
	local keepv = ""											// Accumulating list of vars verified as having numeric suffix
	local nstubs = wordcount("`keep'")
	local prevstub = ""											// Initially there is no previous stub
	
	forvalues h = 1/`nstubs'  {									// We know that `keep' was filled with stubs by caller 
	
		gettoken k keep : keep									// Repeatedly peel off first word of `keep' (list of stubnames)
		if real(substr("`k'",-1,1))<.  {						// If last char of 'k' is numeric (conversion is not missing)
			errexit "Supposed stub '`k'' ends with numeric char – ensure same-initialed stubs are ordered by increasing stublength"
*					 1234567801234567890123456780123456789012345678012345678901234567801234567890
			exit 1
		}
		local lenstub = strlen("`k'")							// Get # of chars in stub
		capture unab vars : `k'*								// Get list of supposed vars with this stub 
		if _rc	{												// If 'unab' finds no vars..
			errexit "Stata finds no vars with wupposed stub"	// Exit with error msg
			exit 1
		}													
												
												// LIST MIGHT INCLUDE ADDITIONAL VARS WITH LONGER STUBS; DON'T ADD THOSE TO 'keepv'
		foreach supvar of local vars  {							// Check each supposed var in turn
			local suffix = substr("`supvar'",`lenstub'+1,.)		// Abstract expected suffix for each var (starts after `lenstub')
			capture confirm integer number `suffix'				// See if whole suffix is an integer number
			if _rc  continue, break								// Suffix is not numeric suggests longer stub so continue w next stub
			else  {  											// Else return code is zero, so suffix is numeric
			   capture confirm variable `supvar'				// This check should be superfluous
			   if _rc==0  local keepv = "`keepv' `supvar'"		// Append supposed var to varlist if its whole suffix is numeric
			   else  {
				  errexit "Supposed variable not confirmed as such: `var'"
			   }
			} //endelse
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





********************************************************************************************************************************





* FOLLOWING IS V9c ATTEMPT AT RE-WRITING 'stubsImpliedByVars' TO HANDLE STUBNAMES WITH INITIAL CHARACTERS THAT COINCIDE;
* EVENTUALLY DISCARDED IN FAVOR OF ADVICE TO USERS TO USE VARLIST FORMAT FOR SHORTER OF ANY TWO SUCH BATTERIES.

/*
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

*/

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

* THIS 'wrapper9C' SUBPROGRAM TRIED TO DEAL WITH POSSIBLY CONFLICTING STUBS OF DIFFERENT LENGTHS. REPLACED BY 'wrapper9b' VERSION


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
		exit 1													// Ensure stublist has no pipes (legacy code)
	}
	
	
	local keepv = ""											// Accumultes a list of existng vars havng expectd numric suffix
																// (typed by user and retrieved by 'syntax' cmd above)	
	local errkept = ""											// List of stubnames rejected by unab as not sufficiently distinct
	local prevkeep = "word("`keep'",1)"							// List of previous stubs to check for matching chars 
	local prevlen = strlen("`prevkeep'")						// Length of previous (initially first) stub in `keep'
	
	while "`keep'"!=""  {										// While `keep' is not empty
																// (We know that `keep' was filled with stubs by calling program) 
	   gettoken kept keep : keep								// Repeatedly peel off first stub held in `keep' list of stubnmes
	   quietly unab K : `kept'*									// `K' will hold a list of vars with the `kept' stubname
																// But this strategy does not work with similar stubs (see below)
	   if _rc  {												// If return code is non-zero..
		  local errkept = "`errkept' `kept'"					// Keep list of stubs deemed insufficiently distinct by 'unab'
		  continue												// Continue with next word in `keep'
	   }
	   
	   local lcs = strlen("`kept'")								// Get length of current stub to see if any later stubs overlap
	   if wordcount("`keep'")>1  {								// Only relevant if there is more than the current one left
		  local wrd = 0											// Count word-gap between two stubs being compared
		  foreach stub  of  local keep  {						// `keep' holds remaining stubs
		  	 local wrd = `wrd' + 1								// Initially the two are adjacent
		  	 local lens = strlen("`stub'")
			 if substr("`stub'",1,min(`lcs',`lens'))==substr("`kept'",1,min(`lcs',`lens')) & `lcs' > `lens'  {
			 	local msg = "Order same-initial stubs with different stublengths in ascendng order of stublen"
						  // 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
				local msg = "`msg'; stub `stub' should preceed `kept'"
				if `wrd' > 1 local msg = "`msg' – and preferably adjacent"
				dispLine "`msg'"
				errexit, msg("`msg'")
		  }
	   }														// Check  
	   
	   
	   foreach k of local K  {									// We build new varnames from each `kept' stub by appending `k'
																
		  local keepv = "`keepv' `k'"							// Append varname to list of names associated with this stub
		  
	   } // next `k'											// Move on to next var associated with this stub

	   if "`keep'"!=""	{										// Move on to next stub, if any, in list of stubs held in `keep'
																// (`keep' is empty after final `kept' has been peeled off)
		  local thisk = word("`keep'",1)						// This is the word that will become `kept' on the next 'while'
		  local lcs = strlen("`thisk'"))						// Length of this (current) stub
		  
		  if substr("`thisk'",1,min(`lcs',`prevlen'))==substr("`prevkeep'",1,min(`lcs',`prevlen')) & `lcs' < `prevlen'  {
																// If length of this current stub is less than len of prev stub..
																// (while strings of length both stubs have in common are the same)
			 errexit "Order same-initial stubs with different stublengths in ascendng order of stublen"
			 exit 1 // 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		  }	 //endif											// Above errexit ensures tractbilty for stubs of differnt lengths
		  
		  else  {
		  	 local prevlen = `lcs'								// Else we assign length of current stub to `prevlen'
			 local prevkeep = "`kept'"
	   } //endif `keep'											// (before moving on to next `while `keep'')
	   
	} //next `while `keep''
	
	if "`errkept'"!=""  {
		dispLine  "Stata reports error `rc' for var(s) `errkept': perhaps ambiguous stubname(s)"
		errexit, msg("Stata reports error `rc' for var(s) `errkept': perhaps ambiguous stubname(s)")
	}															// Call on errexit with optioned msg suppresses 2nd 'dispLine'	
	
	return local keepv `keepv'
	
	scalar GENSTKVARS = "`keepv'"								// Scalar originally intended for 'genstacks'
	
	local skipcapture = "skip"									// If execution reaches this point, there were no captured errors
	
	
	
*  *********************
} //endcapture
*  *********************

capture }														// Cluge to ensure error in 'levelsof' is captured
		

  if _rc & "`skipcapture'"==""  {
	  local rc = _rc
	  errexit "Stata reports error `rc': `kept' may be an ambiguous stubname – try renaming"
	 exit 1 // 12345678901234567890123456789012345678901234567890123456789012345678901234567890 
  }

  
exit															// ATTEMPT TO AVOID "close brace not found" ERROR
	
	
	
end varsImpliedByStubs

*/

****************************************************** END OF SUBPROGRAMS *****************************************************
