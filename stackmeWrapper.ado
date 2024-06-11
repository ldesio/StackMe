
capture program drop stackmeWrapper

*!  This ado file contains program stackmeWrapper that 'forwards' calls on all `cmd'P programs where `cmd' names a stackMe command. 
*!  It also contains subroutines (what Stata calls 'program's) 'varsImpliedByStubs' and 'stubsImpliedByVars' called from genstacksP
 
										// For a detailed introduction to the data-processing objectives of the stackMe package, see
										// 'help stackme'.

program define stackmeWrapper	  		// Called by `cmd'.do (the ado file named for any user-invoked stackMe command) this ado file 
										// repeatedly calls `cmd'P (the program doing the heavy lifting for that command) where context-
										// specific processing generally takes place. (Some command-specific processing does take place
										// in this wrapper, set off by 'if "`cmd'" {...} delimeters). Among stackMe `cmd'P programs,
										// only gendummiesP executes no context-specific code.

*!  Stata version 9.0; stackmeWrapper version 2, updated Apr, Aug '23 and again in Apr-May '24' by Mark from a major re-write in June'22

	version 9.0							// Wrapper for stackMe version 2.0, June 2022, updated in 2023, 2024. Version 2b extracts wor-
										// king data (variables and observations determined by `varlist' [if][in] and options) before 
										// making (generally multiple) calls on `cmd'P', once for each context and stack, saving 
										// processed data for each context in a separate file. This program then merges the working 
										// data back into the original dataset. 
										//
										// StackMe commands are not totally standard in their syntax or data requirements, so this 
										// wrapper program has a number of codeblocks that are specific to particular stackMe commands. 
										// Code that is specific to command genstacks is especially extensive, actually reshaping the 
										// data before calling `genstacksP' to perform context-specific manipulations of the reshaped 
										// data.
										
										//			  Lines suspected of still proving problematic are flagged in right margin      ***
										//			  Lines in need of customizing to specific `cmd's are flagged in right margine   **
										
										
										
*set trace on									
	local filename = c(filename)							// Name of most recently used or saved datafile
	local pwd = c(pwd)										// Directory path to the above file – to ensure not a tempfile
	if "$pwd"==""  global pwd = "`pwd'"						// If directory path is same as found on first entering stackmeWrapper
	if "`pwd'"=="$pwd"  local filename = "`using'" 			// This global is used by genstacksP, which needs to know the name 
															//  of the most recent datafile opened by any stackMe command	

										
										
										
										
									
	
										// (0) Codeblock to process the optionslist transmitted from `cmd', the calling program
										
	gettoken cmd rest : 0									// Get the command name from head of local `0' (what the user typed)
	gettoken anything options : rest, parse(",")			// Split rest between pre- and post-comma (varlist pre, options post)
	if "`options'"==""  {									// If there were no options ...
		gettoken anything mask : anything, parse("\") 		//    retrieve the options mask from the tail of `anything'
	}	
	else gettoken options mask : options, parse("\")		// Otherwise split the options between options proper and Mask

	local mask = strltrim(substr("`mask'", 2, .))			// Strip leading "\" and any space(s) from head of mask
	gettoken prfxtyp mask : mask							// Get `prfxtyp' option+argument (all 1 word) from head of mask
															// (appended to end of opts-list in codeblock (1), line 123)
	gettoken istopt mask : mask								// See if 1st word of remaining `mask' is `multicontxt' flag
	local noMultiContxt = 1									// By default assume this cmd DOESN'T take advantage of multi-contxts
	if "`istopt'"=="multicntxt"  local noMultiContxt = 0	// Reset noMultiContxt switch if `multicntxt' option is present
	else  local mask = "`istopt'" + "`mask'"				// Else re-assemble mask by prepending whatever was in 1st word

	local endLastArg = strrpos("`mask'", ")" )				// Last option with arguments is followed by final ")"
	local optArgs = substr("`mask'", 1, `endLastArg')		// Flags (aka toggles) need different processing than arguments, 
	local firstFlag = wordcount("`optArgs'") + 1			//  so record word # in option-mask where flag options start
															// (additional count due to 2-word options to be subtracted below)
	local optName = ""										// Local holding list of option-names, shorn of any arguments
	foreach optArg of local mask  {							// Extract each word-pair of option-arguments from the option-mask
		gettoken optName arg : optArg, parse( "(" )			// optName preceeds "(", if any, or optName fills whole word
		local optName = lower("`optName'")					// Remove any capitalization used in syntax commands
		if (substr("`optName'",-1,1) != ")" )  {			// `optName' might be 2nd of two arguments – eg " -1) "
			local optNames = "`optNames' `optName'" 		// (in which case it is not appended to the list of `optName's)
		}
		else local firstFlag = `firstFlag' - 1				// Correct `firstFlag' for each 2-word `optArg' included in count
															// (in current stackMe syntax there is always just one of these)
	} //next `optArg'
	
	
	local opt1 = word("`optNames'",1)						// 1st optn has name of `item:'/`var(list):'; (often later replaced 
															//  by the prefix to a var(list) 
																
	
		// ABOUT THE WRAPPER PROGRAM 
		// This program is a wrapper for Version 2.0 stackMe commands. Called by a (generally 10-)line program named 
		// for the stackMe command to be executed, its primary purpose is to group together multiple varlists, all  
		// having the same options and [if][in][weight] specifications, so that each set of varlists can be efficiently 
		// processed during a single pass through the data. Processing is performed by another command-specific 
		// program, referred to as `cmd'P (the original ptvTools program that has been modified to suit the needs 
		// of stackMe). These programs retain the names they had in ptvTools (except for `iimpute', which has been 
		// renamed 'geniimpute' to accord with the naming convention used for other stackMe commands).
		//    Multiple varlists imply multiple option-lists but, because the wrapper brings together varlists with
		// the same options, users can supply a single option-list; and a principal task for the wrapper program is 
		// to keep track of whether options (or option-settings) have been changed, so as to collect a new (set of) 
		// variable list(s) to be processed under control of those revised options. Each varlist, or varlist-option 
		// pair, is separated from the next by double-"or" symbols, ("||"), known as "pipes". This multiple-option 
		// feature of the wrapper program is deliberately obscured in the help files for individual stackMe commands, 
		// being made explicit only in the "Hidden Gems" paragraph towards the end of the stackMe help file.
		//    Multiple varlists have two additional, complementary, functions. The first is to implement any [if][in] 
		// settings by keeping only a working dataset of the dataset, meaning that `if' and `in' expressions do not 
		// need to be evaluated for every observation being processed. The second is to retain in that working dataset 
		// only the variables needed to generate the required data. Both functions reduce the amount of data needing 
		// to be handled by a stackMe command, considerably speeding execution.
		//    Version 2 thus also introduces full [if][in][weight] processing for relevant stackMe commands. 

		// In what follows, lines that might need tailoring to specific stackMe commands are flagged with trailing "**"
	


pause (1)
	
										// (1) Preliminary pre-processing of everything up to and including the first varlist
	
	if substr("`options'",1,5)==", opt"  local options = substr("`options'",11,.) // Strip off the opening ", options(" string
	
	local 0 = "`anything' `options'"						// `0' is where syntax commands expct to find a user-typed commnd-line
															// (cmd-line mostly starts with varlist, but with namelist for genstacks)
	

	syntax anything(id="varlist") [if][in][aw fw pw/], *	// For now we process only varlist/namelist and [ifinweight] components
															// Trailing "*" makes `syntax' transfer any remaining text to `options'
		
	local needopts = 1										// MOST stackMe COMMANDS REQUIRE AN OPTIONS-LIST						
	if "`cmd'"=="gendummies"  local needopts = 0 			// ADD ANY OTHER EXCEPTIONS, AS DISCOVERED								**
	
	local istoptlst = 1										// Switch will be set =0 when the first optionlist has been processed
	
	local lastvarlst = 0									// Switch  will be set =1 if varlist is last in set of multivarlsts
	
	local globalprfx = substr("`cmd'",4,.)					// Used to customize name of global stkname used by some `cmd'Ps
	global `globalprfx'_stkvars = ""						// (here emptied in case previous call on `cmd'P aborted with error)
															// DON'T FORGET TO CUSTOMIZE ANY stkvars PREFIX USED IN other `cmd'P	**
	global limitdiag = ""									// Empty by default (DO NOT EMPTY BEFORE EXITING wrapper)				**
  


*	display as text in smcl

	
	gettoken precomma postcomma : 0, parse(",")				// `0' has pre-processd commnd line, put there at top of this codeblock
	
	if "`postcomma'"==""  {
		if `needopts'  {									// Switch set at top of adofile for `cmds' requiring options lists
*			display as error "Option(s) are required for this command. Exiting `cmd'{txt}" 
			window stopbox stop "Option(s) are required for this command. Exiting `cmd'{sf}" 
		}													// 'No varlist' error handld after ` if "`opts'"!="" ' of codeblock 2)
	}
	
	gettoken opts postpipes : postcomma, parse("||")		// First options-list extends from first "," to "||" or end of command
	local opts = "`opts' `prfxtyp'"							// Append word containing `prfxtyp' option (incl argument) to opts-list

	local restOfCmd = "`precomma'`postpipes'"				// All that remains of first `options' is the "||" that terminated it
															// (next comma now preceeds what was originally any 2nd options-list)
															// (`postpipes' starts with "|| "; ends with end of command)

	local lastvarlst = 0									// Flag will identify final varlist in this (set of) varlist(s)
	

	gettoken anything postpipes : restOfCmd, parse("||")	// Get 1st "`varlist'[if][in][weight]" (all up to "||" or end of `cmd')
															// (it is now in `anything'; its' options are already in "`opts'") 
															// (`anything' comes back into play after 1st `options' are processed)
	if "`postpipes'"==""  local lastvarlst = 1				// If there are no more pipes then this must be final varlist of cmd
	
	if "`anything'"!="" local more = 1						// We have at least one (more) varlist
	else  {													// Varlist or namelist expected
		if "`cmd'"=="genstacks" {
*			display as error "Need varlist or namelist. Exiting `cmd'{txt}"
			window stopbox stop "Need varlist or namelist. Exiting `cmd'"			
		}
		else {
*			display as error "Need varlist. Exiting `cmd'{txt}"
			window stopbox stop "Need varlist. Exiting `cmd'"
		}
	}
	

	local nvarlst = 0										// Count of # of varlists with same opts, accumulated in `multivarlist'


	
	
	while `more'  {											// Binary switch, set =1 six lines up; =0 near end of codeblk 8, below
															// (when no more varlists remain to be processed)
	   if "`anything'"==""  continue, break					// Accidentally discovered fix for `end' glitch sets `more' =1 not 0						
	   local 0 = "`anything'"								// Syntax command operates on contents of `0'; replaces `anything'
	   qui syntax anything/*(id="varlist")*/ [if][in][aw fw pw iw/] // (normally placed there when an adofile or program is entered)
															// (but we need to store those exps as defaults for later varlists)
															// (`syntax' leaves only varlist in `anything')

	   if "`anything'"==""  {								// Any `ifinw' expressions found in `anything' were removed by the	
															// syntax command, so `anything' now contains only a varlist
		  if "`cmd'"=="genstacks"  {						// For genstacks, varlists can be replaced by a namelist
*							   12345678901234567890123456789012345678901234567890123456789012345678901234567890
*			display as error "`cmd' command must be followed by a varlist or namelist – exiting `cmd'{txt}" 
			window stopbox stop "`cmd' commandname must be followed by a variable list – exiting `cmd'"
		  }
		  else  {
*			display as error "`cmd' command must be followed by a variable list – exiting `cmd'{txt}" 
			window stopbox stop "`cmd' commandname must be followed by a variable list – exiting `cmd'"
		  }
	   }
							 
	   if "`if'"!=""  local ifexp = "`if'"					// Updates any previous `if' expression
	   if "`in'"!=""  local inexp = "`in'"					// Ditto for `in' expression
	   if "`weight'"!="" local wetyp = " [`weight'"			// ditto for `we' expression – two items to store: the weight type
	   if "`exp'"!="" local weexp = "=`exp']"				// (types are aw fw pw iw); expression also must be stored

	   local weight = "`wetyp'`weexp'" 						// String together weight components ([ifin] now handled by wrapper)
	   local wt = strltrim(strrtrim("`weight'")) 			// Remove leading " " & trailing blanks
															// `ifinw' will be prepended to `optionsP' if not empty, at end of (2)

	   local saveAnything = "`anything'"					// Save the varlist from being overwritten by a syntax cmd
															// (perhaps redundant as updatd for successive pipe-delimitd varlists)

										

									
									
									
										
pause (2)									
										
										// (2) Pre-process latest optionslist before passing it to `cmd'P (the original program)
							
	   if substr("`opts'",1,1)==","  {						// If `opts' (still) starts with ", " ...
		  local opts = strltrim(substr("`opts'",2,.))		// Trim off leading ",  " 
	   }													// (Did not use `options' local as that gets overwritten by syntax cmd)
		

	   if "`opts'"!=""  {									// If this varlist has any options appended ...
															// (if no new `opt's, `optionsP' will have `opts' set by prev varlst)
	   
		  local 0 = ",`opts' "  							// lower list are common opts
															// put them into `0' where syntax cmd expects to find them

															
//		  ******											
		  syntax, [`mask' NODIAg EXTradiag REPlace NEW MOD NOCONtexts NOSTAcks ///
							prfxtyp(string) * ]				// `mask' was establishd in calling `cmd' and preprocssd in codeblk (0)
//		  ******											// `new' set by either NEWoptions or NEWexpressions; `mod' is default

															// `prfxtyp' was set in `cmd' (the adofile that called this one)
															// `prfxtyp' now is `string'; NODiag is abberviation for limitdiag(0)
															// "*" at end of syntax gets unmatched options placed in local `options'

		  if "`options'"!=""  {								// NOTE: `options' has now been emptied of all valid option names
		    gettoken opt rest : options, parse("(")			// Extract the optname preceeding optn paren, if any, else whole of word
			  if ("`cmd'"=="gendummies"&"`opt'"=="prefix") { //(any remaining might be legacy option-names)
*			  display as error "Option `opt' is option `opt1' in version 2{. Exiting." 
			  window stopbox stop "Option `opt' is option `opt1' in version 2. Exiting`cmd'."	
			}												// (otherwise they are straightforward errors)							****
*		//	display as error "Unexpected or misspelled option-name(s): `options'. Exiting" 			// Undiagnosed bug commentd out
		//	window stopbox stop "Unexpected or misspelled option-name(s): `options'. Exiting`cmd'."	
		  }		
		  if "`cmd'"=="gendist" & "`prefix'"!=""  {
*		   	display as error "Option 'prefix' is now option 'selfplace' in version 2. Exiting"
			window stopbox stop "Option 'prefix' is now option 'selfplace in version 2'. Exiting`cmd'."
		  }	
		  if "`new'"!="" local newoptions = "newoptions" 	// Introduces replacement options and/or expressions
															// 'modoptions' and 'modexpressions' are redundant, as default options
		  local newopt = 0									//`newopt' indicator; set =1 if an options-list is to be treated
		  if "`new'"!=""  {									//  as though it had been specified for the first varlist in a command
			local newopt = 1									// Replace saved options, as tho' latest options were initial options
			if substr("`options",1,3)!="new"  {				// Ensure 'newoptions' option is first one listed (for transparency)
*				display as error "Option {opt new} must be the first option in its option-list. Exiting}" 
				window stopbox stop "Option {opt new} must be the first option in its option-list. Exiting`cmd'."
			}												// (modoptions is redundnt since it initiates action that happens anywy)
		  }
		
		  local optionsP = ""								// Empty the list of options to be transmitted to `cmd'P

		  if "`contextvars'"!=""  {							// Could be turning on use of 'contextvars' in 2nd+ varlist
			capture confirm variable `contextvars'			// (in which case, need variable(s) in `contextvars')
			  if _rc>0  {
*			  display as error "Varlist for contextvars option must contain valid variable names. Exiting Stata.}"
*								12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  window stopbox stop "Varlist for contextvars option must contain valid variable names. Exiting`cmd'."
			}
		  }

		  if "`stackid'"!=""  {								// Could be turning on use of 'stackid' in 2nd+ varlist
			capture confirm variable `stackid'				// (in which case, need a variable in `stackid')
			if _rc>0 & "`cmd'"!="genstacks" {				// (unless cmd is 'genstacks' where name is for generated var)
*			  display as error "stackid option must contain valid variable name{txt}. Exiting."
			  window stopbox stop "stackid option must contain valid variable name. Exiting`cmd'."
			}
			else {
			  capture confirm variable SMstkid
			  if "`stackid'"!="SMstkid" {
*								  12345678901234567890123456789012345678901234567890123456789012345678901234567890
*			  	display as error "Choosing a different stackid name (default name is SMstkid) is not recommended"
				window stopbox rusure "Changing default stackid (default name is SMstkid) is not recommended. Proceed?"
				if _rc>0 exit
			  }
			} //endelse
		  } //endif `stackid'


		  // Here handle negative options, which override any syntax output
		  if ("`nocontexts'"!="") local contextvars = "" 	// For conformity with nostacks (different spelling needed for syntax)
		  if ("`nostacks'"!="") local stackid = "" 			// To handle non-standard (legacy) syntax 			
		  local noopt1s = "no`opt1's"						// Need extra step to get `opt1' name for this `cmd'
		  if ("``noopt1s''"!="") local save`opt1'="" 		// For conformity with nostacks (note double-``'')
		  if ("`nodiag'"!="") local limitdiag = 0		  	// To handle non-standard (legacy) syntax 		
		  
		  global limitdiag = `limitdiag'					// Provides for access by calling routines (currently only genstacks)
  


		  local optNames="`optNames' `extradiag' `replace'"	// `extradiag' & `replace' were added to `cmd' optionlist just above
															// (other such additions are self-executing)

															
		  local i = 0										// Type of argument depends on value of `i' relative to `j'	**

		  local j = `firstFlag'	

		  foreach opt of local optNames	{					// Cycle thru optNames for this command (set in `cmd' program)
		
			 local i = `i' + 1								// Distinguishes options w string args (<j) from toggle opts (>8)
			
			 if `newopt' local save`opt' = ""				// If user optioned `new', empty any saved version of this option
			
			 local saveopt 	= "save`opt'"					// Establish name for associated local
				
			 if "``opt''"!=""  {							// If user specified this option-name (note double ``'')
				if `i'<`j'  	{							// Options 1 to `j'-1: 														
					local `saveopt' = "``opt''"				// Set/replace the var(list)/choice-name stored in `save`opt''
				}
				else  {	
					local `saveopt'  = "`opt'"				// Options `j' to max: set/replace the saved toggle-state (flag-settng)		
				}											// (note single `')
				
			 } //endif ``opt''

			 if "``saveopt''"!=""  {						// Current settings (either new or saved just above) go into `optionsP'
				local `opt' = "``saveopt''"					// Varname or choice-name for options with arguments (note double ``'')
				if `i'<`j'  {
			  	  local optionsP ="`optionsP' `opt'(``opt'')" // Append currnt settngs (either new or set/unset above) to `optionsP'
				}
				else  local optionsP ="`optionsP' `opt'"	// Toggle option has no argument
			 }												// Note that saveno`opt' does not extend `optionsP'
															
		  } //next `opt'
															// Still some additional special cases to go 

															// (after dealing with stacking options)
															
		  if "`cmd'"=="genstacks" { 						// For genstacks, stacked data could be problematic
	
			 global dblystkd = ""							// Global used in cmdP must be empty if not doubly-stacked
		     local dtalabel : data label
			 if "`dtalabel'"!=""  {
			    local word1 = word("`dtalabel'",1)
			    if "`word1'"=="STKD"  {						// Word1 of label has "STKD" if stacked
				   if `limitdiag'!=0  {						// Unless diagnostics have been turned off ... 		 		***
				      display as error  "NOTE: This dataset appears to be stackd (has STKD prefix to dta label. Continue?{txt}"
*									// 12345678901234567890123456789012345678901234567890123456789012345678901234567890
					  window stopbox rusure "This dataset appears to be stacked (has STKD prefix to data label); continue?"
					  if _rc==0  {
						window stopbox rusure "Result will be a doubly-stacked dataset; is that what you want?"
						if _rc>0  {
							display as error "Exiting genstacks"
							error 999
						}
						else  {
							global dblystkd = "dblystkd"
							noisily display "'i' variable will be "S2unit; 'j' variable will be S2stkid"
						}
					  } //endif `rc'
				   } //endif `limitdiag'
			    } //endif substr
			 } //endif `dtalabel'
			 noisily display ".." _continue
		  } //endif `cmd'
			
		  else  {	

			 local dtalabel : data label
			 local word1 = word("`dtalabel'",1)
			 if "`word1'"!="STKD"  {	
				if `limitdiag'!=0  {
					display as error  "NOTE: This dataset appears not to be stacked (no STKD prefix on data label){txt}"
*									// 12345678901234567890123456789012345678901234567890123456789012345678901234567890

*			    	window stopbox note "This dataset appears not to be stacked (no data label)"
					if "`cmd'"=="genplace" capture window stopbox rusure "Command {bf:genplace} requires stacked data; continue anyway?"
					if _rc!=0  error 999
				}
			
			    if "`cmd'"=="genplace" {
				   display as error "Command {bf:genplace} requires stacked data"
				   window stopbox stop "Command {bf:genplace} requires stacked data. Exiting"
*									    // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
				}
			 } // endif `word1...'
		  } //endelse
		  
		  local optionsP =" `ifinw',"+stritrim("`optionsP'") // `ifinw' no longer prefixes `optionsP' as selectn now done by wrapper
		  
		  local istoptlst = 0								 // Flag indicates if first optionlist has been processed (was =1)

	   } //endif "`opts'"!=""								 // Otherwise optionsP will hold options from previous varlst	

	   else  {												 // Varlist/namelist was not followed by options
		  if `istoptlst'==1  {								 // If there were no options specified for first varlist ...
		     local optionsP = strltrim(" `ifinw',")			 // Ensure any `ifinw' are inserted into `optionsP'
		     local istoptlst = 0							 // (and that these are not later schlocked by another such varlist)
		  }
	   } //endelse


 
pause (3)	
		
										// (3) Pre-process latest varlist (there may be multiple varlists per optionlist)

															// `varlist' was put in `anything' before `while' in mid-codeblock (1)
															// (updated 3 lines later and again following `cmd'P call, codeblk (6)
															   	   
	   gettoken precolon postcolon : anything, parse(":")	// See if varlist starts with indicator prefix 
															// `precolon' gets all of varlist up to ":" or to end of string
	   if "`postcolon'"!=""  {							   	// If not empty we have a prefix var
	   
		  if strpos(substr("`postcolon'",2,.), ":")>0  {	// If there is another colon in the same varlist ...
*			  display as error "More than one prefixing colon in varlist starting with <`precolon':>{txt}"
			  window stopbox stop "More than one prefixing colon in varlist starting with <`precolon':>"
		  }

		  local saveAnything ="`anything'" 				   // Update `saveAnything' w latest contribution to `multivarlst'

		  local thisInd = "`precolon'"					   // Store the indicator prefix (dont need to know what it was)

		  if "`prfxtyp'"=="var"  {   					   // Here diagnose prefix error dependng on prefx type, var or other
			  local nonv = ""
			  capture unab thisInd : `thisInd'
			  if _rc>0  {
*				 display as error "Prefix symbol ':' needs preceeding varname(s); you named: `thisInd'{txt}"
				 window stopbox stop "Prefix symbol ':' needs preceeding varname(s). Spelling/capitalization error?" 
*                		  		      12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  }
			  foreach v of local thisInd  {
				 capture confirm variable `v'			   // (in which case, need a variable in `v' 
			  }

			  else  {
				 if "`thisInd'"==""  {					   // Might need to change error msg
*					display as error "Prefix symbol (':') needs stub/prefix)'{txt}"
					if "`cmd'"=="gendummies"  {
						window stopbox stop "Prefix symbol (':') needs preceeding stubname" 									**
					}	
					else if "`cmd'"=="genyhats" window stopbox stop "Prefix symbol (':') needs preceeding yhat prefix"			**
				 } //endif `thisInd'
			  } //end else
				
		  } //endif 'prfxtyp'
			
															 // geniimpute can have multiple prefix vars
		  if wordcount("`thisInd'") > 1 & "`cmd'"!="geniimpute" {
*			 display as error "Multiple 'prefix:' variables. Missing '||' ?{txt}"
			 window stopbox stop "Multiple 'prefix:' variables. Missing '||' ?"								
		  } //endif wordcount
																  
		  if strpos("`postcolon'", "`thisInd'")>0 & "`cmd'"!="genyhats" & "`prfxtyp'"=="var"  {
*			 display as error "Prefix ``opt1'' appears in list of indepvars{txt}"
			 window stopbox stop "Prefix ``opt1'' appears in list of indepvars" 
		  }	
			

		  if "`thisInd'"!="" {								// Here deal with any conflicts arising from a new prefix option
			 if "``opt1''"!=""  & "`prfxtyp'"=="var"  {		// Note double '' to establish whether `opt1' points to anything
				display as error "WARNING: Indicator prefix `thisInd' takes precedence over indicator option ``opt1''{txt}"
				window stopbox note "WARNING: Indicator prefix `thisInd' takes precedence over indicator option ``opt1''" 
			 } 
		  } //endif `thisind'								// NOTE THAT only for genyhats does a prefix not replace `opt1'
															// This warning is only issued if the prefix exists (was optioned)
																
	   } //endif `postcolon'!=""


	   if ("`prfxtyp'" != "none" & "`cmd'"!="gendummies") {	// This error check only needed where varlist prefixes are allowed 
															// (gendummies allows but does not require prefix/option)
		  if "`thisInd'"=="" & "``opt1''"==""  { 			// Neither indicator variable nor depvar option?
*			 display as error "Need initial `opt1': or varname in corresponding option{txt}"
			 window stopbox stop "Need initial `opt1': or varname in corresponding option" 									//	**
		  }
	   }

pause (4)



		
										// (4) Accumulate varlists to be passed to `cmd'P as a set, check for last varlist in set,
										//	   accumulate lists of prefixvars (to not drop if `replace') and vars for working data
										//	   (varlist may actually be a namelist if cmd is genstacks)
										
																// Sets of varlsts have only one optn-list applying to all of them
	    if "`multivarlst'"!=""  local multivarlst = "`multivarlst' ||" 
		else  {													// These pipes are not included in `keep' and `prfxvars' varlists
			local keep = ""										// If first varlist, initialize `keep': list of varnames to be kept
			local prfxvars = ""									// (and list of prefixvars, to be kept if not`replace'd)
		}
		
		if strpos("`saveAnything'", ":")>0	{					// If there is a prefix in the (latest) varlist
																// (`saveAnything' was saved after "while `more' {", way above )
			gettoken precolon postcolon : saveAnything, parse(":")
			if "`prfxtyp'"=="var"  local prfxvars = "`prfxvars' " + "`precolon'" 
																// Accumulate list of prfxvars to be kept but not dropped if `replace'
			local keep = "`keep' " + substr("`postcolon'",2,.)	// (and list of vars to be kept and potentially dropped if optioned)
		}
		
		else local keep = "`keep' " + "`saveAnything'"			// Otherwise all vars must be kept (and potentially dropped as above)
																// (potentially includes stubs of varnames if "`cmd'"=="genstacks")
		
		local multivarlst = "`multivarlst' `saveAnything'"		// Append latest varlist, following "||", if not first in set
		local nvarlst = `nvarlst' + 1							// Count # of varlists in the set defined by having the same options
		

																// We may already know this is last varlist in the set, but ...
		if "`postpipes'"==""  local lastvarlst = 1				// Here is another check; 2 more, more elaborate, to come...
		else  {													// Strip initial "||" if any (prep for post-`cmd'P code in codeblk 7)
		   if substr("`postpipes'",1,2)=="||" local postpipes = strltrim(substr("`postpipes'",3,.))
		}
		
/*																// This codeblock commented out because seemingly redundent
		if `lastvarlst'==0	{									// If not yet established whether current varlist is the last ...
		   gettoken head tail : postpipes, parse("||")			// Looking ahead, extract next inter-pipes text-string; put in `head'
		   if strpos("`head'", ",") > 0  local lastvarlst = 1	// If it contains a comma then it belongs to next (set of) varlist(s)
		}														// (so this varlist is the last in this set of varlists)
*/																





			
pause (5)
			
										// (5) Before calling `cmd'P, finalize variables/cases to be kept in the working dataset
										
																
		if `lastvarlst'  {											// Switch was set =1, above, if is last varlst in set of varlsts
																	// (or if there was only one varlist)

		    local temp = ""											// Name of file/frame with processed vars for first context
		    local appendtemp = ""									// Names of files with processed vars for each subsequent contxt
			

			
		    if "`cmd'"=="genstacks" {								// If dataset is about to be stacked ...	
				
																	// 'genstacks' varlists need special handling ...

				local frstwrd = word("`keep'",1)					// `keep' was filled with varnames or stubs in (4) above
			    local test = real(substr("`frstwrd'",-1,1))			// See if final char of first word is numeric suffix
				local isStub = `test'==.							// `isStub is true if result of conversion is missing

			    if `isStub'  {										// If user named a stub, need list of implied vars to keep
																	// (in working data)
				  local reshapeStubs = "`keep'"						// Stata's reshape expects a list of stubs

				  varsImpliedByStubs `keep'
				  local keepv = r(keepv)
				  if strpos("`keep'",".")>0 local keep = subinstr("`keep'",".","",99)
				} //endif `isStub'									// Eliminate any missing variable indicators from `keep'

				else  {												// Otherwise `frstwrd' is a varname with numeric suffix
																	// (suggesting that other items in `keep' are also varnames)
				  local keepv = "`keep'"							// (command reshape will dianose an error if not so)

				  stubsImpliedByVars, keepv(`keepv')				// Program (below) generates list of stubnames
				  local stublist = r(stubs)							// (one stubname per varlist in genstacks syntax 1)
				  varsImpliedByStubs(`stublist')					// See if both varlists have same number of vars
				  local impliedVars = r(keepv)
				  if wordcount("`impliedVars'") != wordcount("`keepv'"")  {
				  	 display as error ("varlists don't match vars implied by stubs from those varlsts. Use implied vars?")
*                		  		        12345678901234567890123456789012345678901234567890123456789012345678901234567890
					 capture window stopbox rusure("Stubs from varlists imply vars that don't match those varlsts. Use implied vars?")
					 if _rc!=0  error 999							// Exit with error if user says "no"
					 noisily display "Execution continues ..."
				  }
				  if strpos("`stublist'",".")>0 local stublist = subinstr("`stublist'",".","",99)
				  local reshapeStubs = "`stublist'"					// Eliminate any missing variable indicators from `stublist'
				} //endelse											
				
				global reshapeStubs = "`reshapeStubs'"				// Global accessible from 'genstacks'
				
				local nstubs = wordcount("`reshapeStubs'")
				
				forvalues i = 1/`nstubs'  {
					local var = word("`reshapeStubs'",`i')
					capture confirm variable `var'
					if _rc==0  {
						display as error "Variable with stubname `var' already exists"
						error 999
					}
				}
				
				if "`contextvars'"!=""  sort `contextvars'			// Data for genstacks should be sorted only by context
																	// (no stacks as yet)				
				if "`dblystkd'"!=""  gen S2unit = _n				// If data are to be doubly-stacked, use S2unit not SMunit
				else  {											
				   capture confirm variable SMunit					// SMunit should not already exist in unstacked data		   ***
				   if _rc!=0  {										// If there is as yet no SMunit ...
				      generate SMunit = _n							// (also neded by genstacksP)
				   }
				}
				else  {	
					capture confirm string variable SMunit			// Check that SMunit is NOT a string variable
					if _rc==0  {
*						display as error "Variable SMunit should be numeric, not string"
						error 999
					}	
				} //endelse	
				
				local keep = "`keepv' `contextvars' SMunit" 		// No prfxvars or SMstkid in data for cmd genstacks
																	// (But genstacks does need SMunit)										

			} //end if `genstacks'
																	// For other cmds `keep' contains normal varlist(s) & prefixes
			else { 													// (and sorting must include any stackid as part of context)
				
			    if "`contextvars'"!="" sort `contextvars' `stackid' // (`stackid' is empty if data are not stacked)
																	// (but for non-genstacks commands, any stackid adds to context)
				
				if "`prfxvars'"!=""  unab prfxvars : `prfxvars'		// Unabbreviate any prefix varname(s)
																	// (and add to list of vars now stripped of colons & prefixes)
			    if "`prfxtyp'"=="var"  local keep = "`keep' " + "``opt1''"
			    local keep = "`keep' `contextvars' `stackid' `prfxvars'" 
																	//`prfxvars' empty if none
			} //end else
			
		
			local keepv = ""										// Reuse `keepv' to hold accumulating list of vars to be kept
			local prevlen = 0										// Remains unchanged when all duplicates have been removed

			while strlen("`keep'")!=`prevlen'  {					// `keep' may contain duplicate vars/stubs, removed below ...
			   local prevlen = strlen("`keep'")						// (at this point keep contains variables from either source)
			   gettoken first rest : keep, quotes					// Peel off 1st word in `keep'; no quotes around `first'
			   if strpos(" `rest'"," `first'")>0  {					// Apparently need to be sure there is another copy of `first'
			     local rest =subinstr(" `rest'","`first' ","",99)	// Drop up to 99 more occurrncs of `first' by substituting ""
			   }													// (Note surrounding blanks ensure we only replace full words)
			   local keepv = "`first' `rest'"

			} //next while											// Repeat until length of `keep' is unchanged
				
			local keepvars = "`keepv'"								// And store in 'keepvars' for call on `cmd'P
			

			if "`contextvars'"!="" sort `contextvars' 				// Put dataset in context order before enmerating overall _n

		    if "`optionsP'"==""  local optionsP = ", "				// Ensure options start with a comma even if `optionsP' is empty

		    tempfile origdta										// Temporary file in which full dataset will be saved
																	// (at end of this dofile, stkd data will be merged back into it)
																	// Equivalent to 'default' frame which, however, runs more slowly														
			noisily display "." _continue





			
*				    ****
		    quietly save `origdta'								    // Will be merged with processed data after last call on `cmd'P
*				    ****


	

			
					
			if ("`if'"!=""  | "`in'"!="")  keep `if' `in'			// Keep in working dataset only cases to be processed

										
			tempvar _ctx_temp
			
			if ("`contextvars'" == "") {							// Now see what contexts should be cycled thru (dropping rest)
				if ("`stackid'" == "")  {
					gen `_ctx_temp' = 1								// If no contexts or stackid then there is just one context
					local ctxvars = "`_ctx_temp'"					// (don't confuse with `_temp_ctx', generated by _mkcross below)
				}
				else  {												// If there is a stackid option but no contextvars opt,
					if "`cmd'"!="genplace" local ctxvars = "`stackid'" // Unless cmd is genplace, ctxvars contain just a stackid
					else {											// If `cmd' IS genplace then
						gen `_ctx_temp' = 1							// No contextvars means there is just one context
						local ctxvars = "`_ctx_temp'"				// For `genplace' only a stackid means just one context
					}
				}													//  & if command != `genplace', again, is just one context
			} //endif `contextvars'
			
			else {													// else contextvars have been optioned
				if "`cmd'"!="genplace" local ctxvars = "`contextvars' `stackid'" // Unless genplace, supply whatever was optiond
				else  local ctxvars = "`contextvars'"				// For cmd `genplace', stackid must not be included 			 ***
			}														// (even if present or optioned)
		
			tempvar _temp_ctx										// Don't confuse with `_ctx_temp' used as arg for _mkcross
			quietly _mkcross `ctxvars', generate(`_temp_ctx') missing length(20) label ()
			local ctxvar = "`_temp_ctx'"						 	// _mkcross produces sequential IDs for selected contexts
																	// (not to be confused with `ctxvars' used as arg for _mkcross)
	
			quietly sum `ctxvar'
			local nc = r(max)										// This is the number of contexts (`c'), used below and in `cmd'P
			noisily display "." _continue
		

		
	

	
		
																	// Keep in working data only variables to be processed
			if "`cmd'"=="genplace"  {
					
*				  ****
				  keep `keepvars' `ctxvar' `stackid'				// This (and next) command drop all vars not needed for stacking
			} //  ****												// (this cmd – for genplace – uses `stackid'; other cmds do not)
			
*				  ****
			else  keep `keepvars' `ctxvar'							// Keep only vars involved in generating desired results
*				  ****												// (`keepvars' was `keep'd with dups removed before 'save' above
																

																
																
																
																
			if "`cmd'"=="genstacks"  capture drop SMstkid		   // Cluge addresses possibility that SMstkid exists when it should not


			
			
			
			
			

pause (6)	
										// (6) Cycle thru each context in turn, repeatedly calling `cmd'P while appending
										//     relevant options (plus count of # of varlists)		



			if `nc'==1  local noMultiContxt = 1						 // If only 1 context after ifin, make like this was intended
			
			if `noMultiContxt'  local nc = 1						 // If `noMultiContxt' then there is only 1 context
																

			
			forvalues c = 1/`nc'  {									 // Cycle thru successive contexts (`c')
				
				preserve											 // Preserve the working data
				 
				   if !`noMultiContxt' quietly keep if `c'==`ctxvar' // If there ARE multiple contexts, keep only this one

																	// (genstacks and gendummies ignore multiple contexts, if any)

																	


																	
																	
				   ******
				   `cmd'P `multivarlst' `wetyp'`weexp' `optionsP' ctxvar(`ctxvar') nc(`nc') c(`c') nvarlst(`nvarlst')
				   ******

				   

							   
				   
	



				   tempfile i_`c'									// Temporary file i_`c'' keeps vars added to original data
				   quietly save `i_`c''							  	// Save results for this context in tempfile named "i_`c'"

				   if `c'==1  local temp = "`i_`c''"				// Save separately the file holding new vars for 1st context
				   else  {
					  local appendtemp = "`appendtemp' `i_`c''"		// For each following context, extend list of files w saved dta
				   }

				restore												// Restore full dataset from which to extract next context
			  
			} //next context

			local multivarlst = ""									// Re-initialize local holding set of varlists with same options
			local nvarlst = 0										// Ditto for local holding # of varlists having same options
			
			
		} //endif `lastvarlst'			
		

		


	
		
										// (7) Look ahead for next varlst beyond pipes ("||") that maybe ended previous varlst/optns
	
	
																// `postpipes' was stripped of leading "|| ", if any, in codeblk (4)
		gettoken prepipes postpipes : postpipes, parse("||")  	// Look for  next "||", if any, or end of command
		if "`postpipes'"=="" local lastvarlst = 1				// No more pipes, so this one is final varlist in this command
																// (else rest of commnd line, starting with "||", is in 'postpipes')
		if strpos("`prepipes'", ",")>0  {						// If there is a comma before next pipes or end of command, ...										
			gettoken anything opts : prepipes, parse(",")		// Update `anything' w new varlist, etc.; `opts' w new optionslist
		}
		else {
			local anything = "`prepipes'"						// Otherwise there should be, at most, one varlist before next "||"
			local opts = ""										// (and no optionslist)
		}
		


		if "`anything'"==""  {		
			local more = 0										// If no (more) varlist(s), this signals end of while loop
		}
	  

	
	} // next while `more'										// Takes us back to mid-codeblock 0 if there are more varlists ahead
	


	

	
	
	
	
										// (8) After processing last context (6), post-process and merge generated data with original
										//	   (saved) data
										
	if !`noMultiContxt'  {										// Collect up and append files saved for each context in codeblk (6)
																// (If there was only one context then just one was saved)
		preserve

			quietly use `temp', clear							// The tempfile in which the first context was saved in codeblock (6)

			local napp = wordcount("`appendtemp'")				// How many contexts, beyond the first, produced tempfiles
			forvalues i = 1/`napp'  {
				local a = word("`appendtemp'",`i')
				quietly append using `a', nonotes nolabel
				erase `a'										// Maybe "erase `i'" (_mkcross ids are adjacent)			 			***
			} //next 'i'

			quietly save `temp', replace						// File `temp' now contains all new variables from `cmd'P
		
		restore
		
	
	} //endif !`noMultiContxt'
	
	

	

	
pause (9)

	
										// (9) Merge new variables, created in `cmd'P, with original data

	quietly use `origdta', clear								// Restore original data to merge with new vars from `cmd'P

	quietly merge 1:m SMunit using `temp', nogen 				// Here the full temp file is merged back into `origdta'
				
	capture erase `origdta'										// Erase tempfiles
	capture erase `temp'

	
	
end //stackmeWrapper



**************************************************** SUBROUTINES **********************************************************


capture program drop varsImpliedByStubs							

program define varsImpliedByStubs, rclass						// Creates list of number-suffixed varnames corresponding to stubs
																// (checking to make sure all implied vars do have numeric suffix)
*set trace on

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
			if real(substr("`s'",-1,1))==.  continue			// If doesn't have numeric suffix continue with next var
																// (May be version created by reshape(!))
			while real(substr("`s'",-1,1))<.  {					// While last char is numeric (real converstion is not missing)
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
pause sIBV
	syntax , keepv(string)
	
	local keep = "`keepv'"
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
