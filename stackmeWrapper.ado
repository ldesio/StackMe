capture program drop stackmeWrapper

program define stackmeWrapper

*!  stackmeWrapper version 2.0 runs on Stata Version 9 (but faster on Version 16) after major update of stackMe package version 2.0, May 2023
*!  choose tabs 4 at top right of github window

	version 9.0							// Wrapper for stackMe version 2.0, June 2022, updated Apr 2023. Version 2b extracts
										// working data, based on [if][in] and the variables required, before calling `cmd'P;
set tracedepth 3						// then merges the working data back with the original data




										// (0) Codeblock to process the optionslist transmitted by `cmd', the calling program
										
	gettoken cmd rest : 0									// Get the command name from head of local `0' (what the user typed)
	gettoken anything options : rest, parse(",")			// Split the rest between `anything' (varlist) and options
	if "`options'"==""  {									// If there were no options ...
		gettoken anything mask : anything, parse("\") 		// retrieve the options mask from the tail of `anything'
	}
	
	else gettoken options mask : options, parse("\")		// Otherwise split the options between options proper and Mask
	local mask = strltrim(substr("`mask'", 2, .))			// Strip leading "\" and any space(s) from head of mask
	gettoken prfxtyp mask : mask							// Get `prfxtyp' option+argument (all 1 word)) from head of mask
															// (will be placed after last option, 9th line of codeblock 1)
	local endLastArg = strrpos("`mask'", ")" )				// Last option with arguments is followed by final ")"
	local optArgs = substr("`mask'", 1, `endLastArg')		// Flags (aka toggles) need different processing than arguments, 
	local firstFlag = wordcount("`optArgs'") + 1			//  so record word # in option-mask where flag options start
			
	local optName = ""										// Local holding list of option-names, shorn of any arguments
	foreach optArg of local mask  {							// Extract each word-pair of option-arguments from the option-mask
		gettoken optName arg : optArg, parse( "(" )			// optName preceeds "(", if any, or optName fills whole word
		local optName = lower("`optName'")					// Remove capitalization used for syntax commands
		if (substr("`optName'",-1,1) != ")" )  {			// `optName' might be 2nd of two arguments – eg " -1) "
			local optNames = "`optNames' `optName'" 		// (in which case it is not appended to list of `optName's)
		}

	} //next `optArg'
	
	
	local prfx = word("`optNames'",1)						// 1st optn has name of `item:'/`var(list):' prefix to a var(list)
																
	
		// ABOUT THE WRAPPER PROGRAM 
		// This program is a wrapper for Version 2.0 stackMe commands. Called by a 10-line program named for the
		// stackMe command to be executed, its primary purpose is to group together multiple varlists, all having  
		// the same options and [if][in][weight] specifications, so that each set of varlists can be efficiently 
		// processed during a single pass thru the data. Processing is performed by another command-specific 
		// program, referred to as `cmd'P (the original ptvTools program that has been modified to suit the needs 
		// of stackMe 2.0). These programs retain the names they had in ptvTools (except for `iimpute', which has been 
		// renamed 'geniimpute' to accord with the naming convention used for other stackMe commands).
		//    Multiple varlists imply multiple option-lists but, because the wrapper brings together varlists with
		// the same options, users can supply a single option-list; and a principal task for the wrapper program is 
		// to keep track of whether options (or option-settings) have been changed, so as to collect a new (set of) 
		// variable list(s) to be processed under control of those revised options. Each varlist, or varlist-option 
		// pair, is separated from the next by double-"or" symbols, ("||"), known as "pipes".
		//    Multiple varlists have two additional, complementary, functions. The first is to implement any [ifin] 
		// setting by keeping only a working dataset, meaning that `if' and `in' expressions do not need to be 
		// evaluated for every case. The second, is to retain in that working dataset only the variables needed to 
		// generate the required data. Both functions reduce the amount of data to be handled by a stackMe command, 
		// speeding execution.
		//    Version 2 thus also introduces full [if][in][weight] processing for relevant stackMe commands. 

		// In what follows, lines that might need tailoring to specific stackMe commands are flagged with trailing "**"
	

	
	
	
										// (1) Preliminary pre-processing of everything up to and including the first options-list
	
	if substr("`options'",1,5)==", opt"  local options = substr("`options'",11,.) // Strip off the opening ", options(" string
	
	local 0 = "`anything' `options'"						// `0' is where syntax commands expect to find a user-typed command-line
	

	syntax anything(id="varlist") [if][in][aw fw pw iw/], *	// For now we process only varlist and [ifinweight] components
															// Trailing "*" makes `syntax' transfer any remaining text to `options'
		
	local needopts = 1										// MOST stackMe COMMANDS REQUIRE AN OPTIONS-LIST						
	if "`cmd'"=="gendummies"  local needopts = 0 			// ADD ANY OTHER EXCEPTIONS, AS DISCOVERED								**
	
	local noMultiContxt = "`cmd'"!="genyhats" & "`cmd'"!="geniimpute" // (equally, the user could select/option just one context)	**
															// "THIS LEAVES A '1' IF `cmd'P DOESN'T GENERATE NEWVAR(S) BY CONTEXT

	local istoptlst = 1										// Switch set =0 when the first optionlist has been processed
	
	local lastvarlst = 0									// Switch set =1 if varlist to be passed to `cmdP' is last (in set)
	
	local globalprfx = substr("`cmd'",4,.)					// Used to customize name of global stkname used by `cmd'P
	global `globalprfx'_stkvars = ""						// Just in case `cmd'P aborted with error sometime previously
															// DON'T FORGET TO CUSTOMIZE ANY stkvars PREFIX USED IN `cmd'P			**

	display as text in smcl

	
	gettoken precomma postcomma : 0, parse(",")				// `0' has pre-processd commnd line, put there at top of this codeblock
	
	if "`postcomma'"==""  {
		if `needopts'  {									// Switch set at top of adofile for `cmds' requiring options lists
			display as error "Option(s) are required. Exiting `cmd'{sf}" 
			window stopbox stop "Option(s) are required. Exiting `cmd'{sf}" 
		}													// 'No varlist' error handld after ` if "`opts'"!="" ' of codeblock 2)
	}
	
	gettoken opts postpipes : postcomma, parse("||")		// First options cmd extends from first "," to "||" or end of command
	local opts = "`opts' `prfxtyp'"							// Append word containing `prfxtyp' option (+ argument) to opt-list

	local restOfCmd = "`precomma'`postpipes'"				// All that remains of first `options' is the "||" that terminated it
															// (next comma now preceeds what was originally the 2nd options-list)
															// (`postpipes' starts with "|| "; ends with end of command)

	local lastvarlst = 0									// Flag will identify final varlist in this (set of) varlist(s)
	

	gettoken anything postpipes : restOfCmd, parse("||")	// Get 1st "`varlist'[if][in][weight]" (all up to "||" or end of `cmd')
															// (it is now in `anything'; its's options are already in "`opts'") 
															// (`anything' comes back into play after 1st `options' are processed)
	if "`postpipes'"==""  local lastvarlst = 1				// If there are no more pipes then this must be final varlist of cmd
	
	if "`anything'"!="" local more = 1						// We have at least one varlist
	else  {
		display as error "Need varlist. Exiting `cmd'"
		window stopbox stop "Need varlist. Exiting `cmd'"
	}
	

	local nvarlst = 0										// Count of # of varlists with same options, accumulated in `multivarlist'


	
	
	while `more'  {											// Binary switch, set =1 above and =0 near end of codeblock (8), below
															// (when no more varlists remain to be processed)
										

										
	  local saveAnything = "`anything'"						// Save `anything' because ...
	  local 0 = "`anything'"								// Syntax command operates on contents of `0'; replaces `anything'
	  qui syntax anything(id="varlist") [if][in][aw fw pw iw/] // (normally placed there when an adofile or program is entered)
															// (but we need to store those exps as defaults for later varlists)
															// (`syntax' leaves only varlist in `anything')

	  if "`anything'"==""  {								// Any `ifinw' expressions found in `anything' were removed by the	
															// syntax command, so `anything' now contains only a varlist
	      display as error "stackMe commandname must be followed by a variable list – exiting `cmd'" 
		  window stopbox stop "stackMe commandname must be followed by a variable list'
	  }
							 
	   if "`if'"!=""  local ifexp = "`if'"					// Updates any previous `if' expression
	   if "`in'"!=""  local inexp = "`in'"					// Ditto for `in' expression
	   if "`weight'"!="" local wetyp = " [`weight'"			// ditto for `we' expression – two items to store: the weight type
	   if "`exp'"!="" local weexp = "=`exp']"				// (types are aw fw pw iw); expression also must be stored

	   local weight = "`wetyp'`weexp'" 						// String together weight components ([ifin] now handled by wrapper)
	   local wt = strltrim(strrtrim("`weight'")) 			// Remove leading " " & trailing blanks
															// `ifinw' will be prepended to `optionsP' if not empty, at end of (2)

	   local saveAnything = "`anything'"					// Save the varlist from being overwritten by a syntax cmd

										

									
									
										
										
										
										
										// (2) Pre-process latest optionslist before passing it to `cmd'P (the original program)
							
	   if substr("`opts'",1,1)==","  {						// If `opts' (still) starts with ", " ...
		  local opts = strltrim(substr("`opts'",2,.))		// Trim off leading ",  " 
	   }													// (Did not use `options' local as that gets overwritten by syntax cmd)
		

	   if "`opts'"!=""  {									// If this varlist has any options appended ...
															// (if no new `opt's, `optionsP' will have `opts' set by prev varlst)
	   
		  local 0 = ",`opts'"								// put them into `0' where syntax cmd expects to find them

															
		  syntax, [ `mask' NODiag ] prfxtyp(string) *		// `prfxtype' was set in `cmd' (the adofile that called this one)
															// `prfxtyp' now is `string'; NODiag is abberviation for limitdiag(0)
															// "*" at end of syntax gets unmatched options placed in local `options'

		  if "`options'"!=""  {								// NOTE: `options' has now been emptied of all valid option names
			display as error "Unexpected or misspelled option-name(s): `options'{sf}" 
			 window stopbox stop "Unexpected or misspelled option-name(s): `options'"	
		  }		
				
		  local new = 0										//`newoptions' indicator; set =1 if an options-list is to be treated
		  if "`newoptions'"!=""  {							//  as though it had been specified for the first varlist in a command
			local new = 1									// Replace saved options, as tho' latest options were initial options
			if substr("`options",1,3)!="new"  {				// Ensure 'newoptions' option is first one listed (for transparency)
				display as error "Option {opt new:options} must be the first option in its option-list" 
				window stopbox stop "Option {opt new:options} must be the first option in its option-list"
			}
		  }
		
		  local optionsP = ""								// Empty the list of options to be transmitted to `cmd'P

		  													// Here handle negative options, which override any syntax output
		  if ("`nocontexts'"!="") local contextvars = "" 	// For conformity with nostacks (different spelling needed for syntax)
		  if ("`nostacks'"!="") local stackid = "" 			// To handle non-standard (legacy) syntax 			
		  local noprfxs = "no`prfx's"						// Need extra step to get `prfx' name for this `cmd'
		  if ("``noprfxs''"!="") local save`prfx'="" 		// For conformity with nostacks (note double-``'')
		  if ("`nodiag'"!="") local limitdiag = 0		  	// To handle non-standard (legacy) syntax 		

		  
		  local i = 0										// Type of argument depends on value of `i' relative to `j'				**

		  local j = `firstFlag'	

		  foreach opt of local optNames	{					// Cycle thru optNames for this command (set in stackmeCaller)
		
			 local i = `i' + 1								// Distinguishes options w string args (<9) from toggle opts (>8)
			
			 if `new' local save`opt' = ""					// If user optioned `new', empty any saved version of this option
			
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
		  
		  if ("`stackid'" == "") {							// If `stackid' not optioned ...
		     capture confirm variable stackMe_stkid			// Version 2 default
			 if !_rc {
			   // action if exists
			    local stackid = "stackMe_stkid"				// This needs to be inserted into other `cmd's							***
			 }

			 else {											// Go thru available sources of `stackid'
			   // action if not
			   local stkid = ""
			   local dtalabel : data label
			   if "`dtalabel'"!=""  {
				  gettoken pre_ post_ : dtalabel, parse("_")
				  if "`pre_'"=="stackMe"  {
					 gettoken stackme rest : dtalabel, parse("_") // Parse on "_" so "stackme", if any, is found at head of 'dtalabel'

					 if "`stackme'"=="stackme" | "`stackme'"=="stackMe"  {
					  	local stackid = substr("rest",2,.) // `stackid' held in data label follows "_" in first word of label
					 }

					 capture confirm variable stackid
					 if _rc  /*& `unstkdNote'==""*/  {		// Only issue this note first time (commentd out 'cos hopefully redundnt)
					    stackid = ""
						if ("`nostacks'"=="") {
						   noisily display "NOTE: This dataset appears to be unstacked{sf}"
						   window stopbox note "This dataset appears to be unstacked"
						}
*					 local unstkdNote = "done" /*Commented out because hopefully redundant*/
					 }										// (unless deliberately ignoring stack differences)
				  } //endif `pre_-'

				  else  {
					 if ("`nostacks'"=="") {
					 	noisily display  "NOTE: This dataset appears to be unstacked{sf}"
						window stopbox note "This dataset appears to be unstacked"
					 }
				  } //end else											// (unless deliberately ignoring stack differences)
			   } //endif `dtalabel'
			 } //end else
		  } //endif `stackid'
		  
		 
		  local optionsP =" `ifinw',"+stritrim("`optionsP'") // `ifinw' no longer prefixes `optionsP' as selectn now done by wrapper
		  
		  local istoptlst = 0								 // Flag indicates first optionlist has been processed
															 // (after that, every option must be checked to see if previously set)
															
	   } //endif "`opts'"!=""								 // Otherwise optionsP will hold options from previous varlst	

	   if `istoptlst'==1  {									 // If there were no options specified for first varlist ...
		  local optionsP = strltrim(" `ifinw',")			 // Ensure any `ifinw' are inserted into `optionsP'
		  local istoptlst = 0								 // (and that these are not later schlocked by another such varlist)
	   }

	   
	   
								

		
		
										// (3) Pre-process latest varlist (there may be multiple varlists per optionlist)

															   // `varlist' was put in `anything' before `while' in mid-codeblock (1)
															   // (updated 3 lines later and again following `cmd'P call, codeblk (6)
															   
	   if `nvarlst'==0  {									   // If this is NOT 2nd or later varlist in set of varlists
	   
	     gettoken precolon postcolon : anything, parse(":")	   // See if varlist starts with indicator prefix 
															   // `precolon' gets all of varlist up to ":" or to end of string
	     if "`postcolon'"!=""  {							   // If not empty we have a prefix var

			local anything=strltrim(substr("`postcolon'",2,.)) // Strip leading colon from varlist leaving just battery vars 
			local saveAnything ="`anything'" 				   // Put it in `saveAnything' to be transferred to `multivarlst'

			local thisInd = "`precolon'"					   // Store the indicator prefix (dont need to know what it was)

			if "`prfxtyp'"=="var"  {   						   // Here diagnose prefix error dependng on prefx type: var or other
				capture confirm variable `thisInd'
				local rc = _rc
				if wordcount("`thisInd'") == 0 | `rc'>0  {
					display as error "Prefix symbol ':' needs preceeding varname. Spelling/capitalization error?{sf}"
					window stopbox stop "Prefix symbol ':' needs preceeding varname. Spelling/capitalization error?" 	
				}

				else  {
					if "`thisInd'"==""  {						// Might need to change error msg
						display as error "Prefix symbol (':') needs preceeding itemname{sf}"
						if "`cmd'"=="gendummies"  window stopbox stop "Prefix symbol (':') needs preceeding stubname" 				**
						if "`cmd'"=="genyhats"    window stopbox stop "Prefix symbol (':') needs preceeding yhat prefix"			**
					} 
				} //end else
			} //endif 'prfxtyp'
			
					
			if wordcount("`thisInd'") > 1 & "`cmd'"!="geniimpute"  {
				window stopbox stop "Multiple 'prefix:' variables. Missing '||' ?"								
			} //endif wordcount
																  
			if strpos("`anything'","`thisInd'")>0  {
				window stopbox stop "Prefix ``prfx'' appears in list of indepvars" 
			}	
			

			
			if "`thisInd'"!="" {								// Here deal with conflicts arising from a new prefix option
			   local isprfx = "isprfx"							// Activate the `isprfx' local, flagging prefix presence to `cmd'P
			   if "``prfx''"!=""  {								// Note double '' to establish whether `prfx' points to anything
				  window stopbox note "WARNING: Indicator prefix takes precedence over indicator option" 
																// This warning is only issued if the prefix exists (was optioned)
				  if "`optionsP'"!=""  {						// If there are any existing options ...
					local optname = strupper(substr("`prfx'",1,3))+substr("`prfx'", 4, .) // Need capitalized chars for syntax cmd
					local 0 = " `optionsP'"						// Put accumulatd optns into `0' where syntax command can find them
					syntax [anything][if][in][aw pw fw iw],`optname'(name) * // Extract existing `prfx' option from options list
					local optionsP = "`wt', `options'" 			// Final "*" on syntax cmd puts unmatched options into `options'
				  }												// (replace any `wt', stored earlier, siftd out by syntax cmmnd)
			   } //endif ``prfx''
			} //endif `thisind'
			else  local isprfx = ""								// If no prefix variable, cancel the isprfx flag

			if "`thisInd'"!=""  {								// If there was a prefix indicator variable 
				local add2 = "`prfx'(`thisInd') `isprfx'"		// Flag so `cmd'P will know that 1st varlist is prefixed
			}													// 'thisInd' isn't actual option so not saved in `save`opt''
		
			local optionsP = " `optionsP' `add2'"				// `optionsP', to append to `cmd'P', has "`ifinw'," before optns	
																// (and here has `isprfx' appended, if varlist was prefixed)	
		 } //endif `postcolon'!=""

	   } //endif `nvarlst==0'									// If this is 2nd+ multivarlst it retains any prefix variables

	
	   if ("`cmd'"!="gendummies")  {							// This error check not needed for gendummies
		  if "`thisInd'"=="" & "``prfx''"==""  { 				// Neither indicator variable nor depvar option?
			 display as error "Need initial 'depvar:' or varname in corresponding option{sf}"
			 window stopbox stop "Need initial depvar: or varname in corresponding option" 										//	**
		  }
	   }

		
		

		
															
		
										// (4) Accumulate any varlists to be passed to `cmd'P as a set, check for last varlist in set
		
																// Sets of varlsts have only one optn-list applying to all of them
		if "`multivarlst'"!=""  local multivarlst = "`multivarlst' ||" 
		local multivarlst = "`multivarlst' `saveAnything'"		// Append latest varlist, following "||", if not first in set
																// (`saveAnything' was saved after "while `more' {", way above )
		local nvarlst = `nvarlst' + 1							// Count # of varlists in the set defined by having the same options
		

																// We may already know this is last varlist in the set, but ...
		if "`postpipes'"==""  local lastvarlst = 1				// Here is another check; 2 more, more elaborate, to come...
		else  {													// Strip initial "||" if any (prep for post-`cmd'P code in codeblk 7)
		   if substr("`postpipes'",1,2)=="||" local postpipes = strltrim(substr("`postpipes'",3,.))
		}

		if `lastvarlst'==0	{									// If not yet established whether current varlist is the last ...
		   gettoken head tail : postpipes, parse("||")			// Looking ahead, extract next inter-pipes text-string; put in `head'
		   if strpos("`head'", ",") > 0  local lastvarlst = 1	// If it contains a comma then it belongs to next (set of) varlist(s)
		}														// (so this varlist is the last in this set of varlists)
																

		
		if `lastvarlst'  {										// Switch was set =1, above, if this is last varlist in set of varlsts
																// (or if there was only one varlist)
			if "`optionsP'"==""  local optionsP = ", "			// Ensure options start with a comma even if `optionsP' is empty




			
		
	
										// (5) Before calling `cmd'P, drop the variables/cases not needed in the working dataset
			tempvar _unit
			gen `_unit' = _n										// unit ID that will govern merge of imputed vars with origdta
	
			tempfile origdta										// Equivalent to 'default' frame for versions supporting frames	
			quietly save `origdta'

			local temp = ""											// Name of file/frame with processed vars for first context
			local appendtemp = ""									// Names of files with processed vars for each subsequent contxt
	
			local prfxvar = ""										// By default there is no prefixvar for this varlist
			if "``prfx''"!="" & "`prfxtyp'"=="var"  local prfxvar = "``prfx''" // Update the default if overriden by user
	
			local keep = strtrim(stritrim("`prfxvar' `contextvars' `stackid'" + subinstr("`multivarlst'", "||", " ", 99))) 
																	// 'keep' gets all varnames, stripped of pipes and extra spaces
																	   
			if "`prfxtyp'"=="othr"  {								// But there might still be non-variable prefixes included
				foreach word of local keep  {						// (note that `prfxtyp' is a fixed feature of this `cmd')
					gettoken head tail : word, parse(":")			// If there is a "`string':" prefix, substitute a null string
					if "`tail'"!=""  local keep = subinstr("`keep'", "`head':", "", 1) // (operationalized by "")
				}
			}

			else local keep=stritrim(subinstr("`keep'",":"," ",99)) // Otherwise replace each colon with just one space
		
			unab varlist : `keep'									// Unabbreviate varnames & fill in ranges of implied varnames
		
			local keepvars = ""
			foreach var of local varlist  {							// This varlist will have all vars mentioned in a multi-varlist
				local sublst = subinstr("`varlst'","`var'", "", 1)	// Replace each `var' with "", effectively dropping that copy
				if strpos("`sublst'","`var'")==0  local keepvars = "`keepvars' `var'" 
			}														// And add it to 'keepvars' if there is no other copy


			
			if ("`if'"!=""  | "`in'"!="")  keep `if' `in'			// Keep in working dataset only cases to be processed
			keep `_unit' `depvar' `keepvars' `ctxvar'				// Keep only vars involved in generating desired results			
			
			
										
			if ("`contextvars'" == "") {							// Now see what contexts should be cycled thru (dropping rest)
				if ("`nostacks'" != "") {
					tempvar _stk_temp
					gen `_stk_temp' = 1
					local stackvars = "`_stk_temp'"
				}
				else {
					local stackvars = "`stkid'"
				}
			}
			else {
				local stackvars = "`contextvars' `stkid'"
			}		
		
			tempvar _temp_ctx
			if ("`stackvars'" == "") {
				gen `_temp_ctx' = 0
				quietly replace `_temp_ctx' = 1 `if' `in'
				local ctxvar = "`_temp_ctx'"
			}
			else {
				quietly _mkcross `stackvars' `if' `in', generate(`_temp_ctx') missing length(20) label ()
				local ctxvar = "`_temp_ctx'"						// _mkcross includes only selected, producing sequential IDs
			}

			local contextlabel : label (`ctxvar') 1					// *** DON'T KNOW WHAT TO DO WITH THIS VARIABLE LABEL 			***
														
			quietly sum `ctxvar'
			local nc = r(max)										// This is the number of contexts, used below and in `cmd'P
		

		
		
	

	
										// (6) Cycle thru each context in turn, repeatedly calling `cmd'P while appending
										//     relevant options (plus count of # of varlists)		
		
			forvalues c = 1/`nc'  {
				
				preserve
				
					quietly keep if `c'==`ctxvar'
				

				
*					******
					`cmd'P `multivarlst' `optionsP'  prfx(`prfx') nvarlst(`nvarlst') ctxvar(`ctxvar') nc(`nc') c(`c') 
*					******											// `isprfx', if any, is last item in `optionsP'
				
			
				
					tempfile i_`c'																																												  // Keep just additions to original data
					quietly save `i_`c''							// Save results for this context in tempfile named "i_`c'"

					if `c'==1  local temp = "`i_`c''"				// Save separately the file holding imputed data for 1st context
					else  {
						local appendtemp = "`appendtemp' `i_`c''"	// For each following context, extend list of files w imputd dta
					}

				restore
			  
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

		if "`anything'"==""  local more = 0						// If no (more) varlist(s), this signals end of while loop
																// (otherwise 'more' still =1, signallng another varlist to process)
															  															  
	
	} // next while `more'										// Takes us back to mid-codeblock 0 if there are more varlists ahead
	
	

	
	
	
	
	
										// (8) After processing last context (6), post-process and merge generated data with original
	
	if `noMultiContxt'  {										// If JUST ONE CONTEXT was processed as  then ...
	
		tempfile temp											// This is the whole working dataset for single context analyses
		
		quietly save `temp'	
				
	}
	
	else  {														// If MULTIPLE CONTEXTS were used then separate contexts were saved
																// Collect up and append files saved for each context in codeblk (6)
																
		preserve

			quietly use `temp', clear							// The tempfile in which the first context was saved in codeblock (6)

			local napp = wordcount("`appendtemp'")				// How many contexts, beyond the first, produced tempfiles
			forvalues i = 1/`napp'  {
				local a = word("`appendtemp'",`i')
				quietly append using `a', nonotes nolabel
				erase `a'										// Maybe "erase `i'" (_mkcross ids are adjacent)			 		***
			} //next 'i'


			quietly save `temp', replace
		
		restore
		
	
	} //endif `noMultiContxt'
	
	
	
										// (9) Merge generated data with original data

	quietly use `origdta', clear								// Restore the original data and merge with working data
	
	quietly merge 1:1 `_unit' using `temp', nogen				// Here the appropriate temp file is merged back with `origdta'
				
	erase `origdta'												// Erase tempfiles
	erase `temp'
	drop `_unit'												// Drop tempvar '_unit'	
	capture drop __000*											// Drop any other remaing tempvars
	capture label drop __000*									// (and their labels)
	

	
	
	
										
										// (10) Execute next lines only following final call on `cmd'P
										
	
	if ("`replace'"=="replace") {
	if `limitdiag' !=0  " noisily display " As requested, dropping {result:`keepvars'}...{break}"
		drop `keepvars'
	}

	if (`limitdiag'!=0)  noisily display _newline "done."
	else noisily display " "
	
	if "$`globalprfx'_stkvars"!="" global `globalprfx'stkvars = "" // SO FAR USED ONLY ONLY IN genyhatsP)							**


end //stackMeWrapper


