

capture program drop stackmeWrapper

*!  This ado file contains program stackmeWrapper that 'forwards' calls on all `cmd'P programs where `cmd' names a stackMe command. 
*!  Also subroutines (what Stata calls 'program's) 'varsImpliedByStubs' and 'stubsImpliedByVars' called frm genstacks and genstacksP
*!  as well as from this wrapper program.
*!  Version 4 replicates normal Stata syntax on every varlist of a V4 command (nothing is remembered from previous varlists).d
*!  Version 5 simplifies version 4 by limiting positioning of ifinwt expressions to 1st varlist and options to last varlist
 
										// For a detailed introduction to the data-processing objectives of the stackMe package, 
										// see 'help stackme'.

program define stackmeWrapper	  		// Called by `cmd'.do (the ado file named for any user-invoked stackMe command) this ado  
										// file repeatedly calls `cmd'P (the program doing the heavy lifting for that command) where 
										// context-specific processing generally takes place. It also parses the user-supplied 
 										// stackMe syntax and sets up options and varlist(s) for the call on `cmd'P. 				***

*!  Stata version 9.0; stackmeWrapper version 4, updated Apr, Aug '23 & again Apr-Sept '24 by Mark from major re-write in June'22

	version 9.0							// Wrapper for stackMe version 2.0, June 2022, updated in 2023, 2024. Version 2b extracts 
										// working data (variables and observations determined by `varlist' [if][in] and options) 
										// before making (generally multiple) calls on `cmd'P', once for each context and (generally) 										
										// stack, saving processed data for each context in a separate file. This program then merges 
										// the working data back into the original dataset. Care is taken to restore the original 
										// data before terminating after any anticipated error. (Unanticipated errors can leave the
										// user confronting a working dataset consisting of a single context and stack).
										// 
										// StackMe commands are not totally standard in their syntax or data requirements, so this 
										// wrapper program has a number of codeblocks specific to particular stackMe commnds. These
										// codeblocks can be found by searching on the string ' if "`cmd'" '. Code specific to
										// command 'genstacks' is especially extensive since that command can (indeed should) be
										// accompanied by a list of stubnames that are not (yet) variables. The alternative syntax
										// of pipe-delimeted batteries of vars is provided only for conformity with other commands.
										// 
										// Additional introductory text can be found following codeblock (0), below.
										
										//			  Lines suspected of still proving problematic are flagged in right margin      ***
										//			  Lines needing customizing to specific `cmd's are flagged in right margin    	 **
										
										
										
pause (0)										
	

										// (0)  Preliminary codeblock establishes name of latest data file used or saved by any 
										// 		stackMe command and of other globals and locals needed throughout

	local using = c(filename)								// Path+name of datafile most recently used or saved by any Stata cmd.
	local nameloc = strrpos("`using'","`c(dirsep)'") + 1	// Position of first char following final "/" or "\" of directory path
	if strpos("`using'", c(tmpdir)) == 0  {					// Unless c(tmpdir) is contained in dirpath
		global filename = substr("`using'",`nameloc',.)		// Update filename with name most recently saved or used
	}														// (needed by genstacks caller as default name for newly-stckd dtafile)
*	global limitdiag = ""									// Empty by default (DO NOT EMPTY BEFORE EXITING wrapper)				**
	global exit = 0											// Used to signal whether called 'cmd'P exited due to 'exit' command
	
	local prfxvars = ""										// Cumulative list of prefix vars
	local keepwtv = ""										// Will hold list of weightvars, to be kept in working data
	local wtexplst = ""										// Will hold list of weight expressions to be passed to `cmd'P
	
	local nvarlst = 0										// Count of varlsts in the multivarlst (defaults to 0, flaggng an error)

	capture confirm variable SMstkid						// See if dataset is already stacked
	if _rc  local stackid = ""								// `stackid' holds varname SMstkid or indicates its absence if empty
	else  {
		local stackid = "SMstkid"							// Else record name of stackid in local stackid

		capture confirm variable S2stkid					// See if dataset is already doubly-stacked
		if _rc  local dblystkd = ""							// if not, empty the indicator
	}
	else local dblystkd = "dblystkd" 						// Else record name of double-stack id in local dblystkd
	global dblystkd = "`dblystkd'"							// And make a global copy accessible to genstacksP

	local multivarlst = ""									// Local that will hold (list of) varlist(s)
	local noweight = "noweight"								// Default setting assumes no weight expression appended to any varlist
	
	local wtvar =										   ///
	"wtvar1 wtvar2 wtvar3 wtvar4 wtvar5 wtvar6 wtvar7 wtvar8 wtvar9 wtvar10 wtvar11 wtvar12 wtvar13 wtvar14 wtvar15"
	global wtexp =										   /// Make wtexp a global accessible from `cmd'P
	"wtexp1 wtexp2 wtexp3 wtexp4 wtexp5 wtexp6 wtexp7 wtexp8 wtexp9 wtexp10 wtexp11 wtexp12 wtexp13 wtexp14 wtexp15"
	local varmis = 										   ///
	"varmis1 varmis2 varmis3 varmis4 varmis5 varmis6 varmis7 varmis8 varmis9 varmis10 varmis11 varmis12 varmis13 varmis14 varmis15"
	 
	forvalues i = 1/15  {									// All 3 lists need to be initialized to null
		local wtvar`i' = ""	
		local wtexp`i' = ""
		local varmis`i' = ""
	}														// By initializing the above we ensure Stata knows they are local names

	local needopts = 1										// MOST COMMANDS REQUIRE OPTIONS-LIST (exceptns at top of codeblk 0.1)

	
	
	
															
pause (0.1)	

										// (0.1) Codeblock to pre-process the command-line passed from `cmd', the calling program.
										//       It divides up that line into its basic components: `cmd' (the stackMe commend name);
										//	    `anything' (the combined varlist/namelist and ifinwt expression); the comma followed 
										//	     by `options' appended to that expression; the syntax `mask' appended to the above;  
										//	     and two afterthoughts that are placed between the options and the mask.
											
	gettoken cmd rest : 0									// Get the command name from head of local `0' (what the user typed)
															// (this command primes local `rest' for the opening while loop, below)
	if "`cmd'"=="gendummies"  local needopts = 0 			// ADD ANY OTHER EXCEPTIONS, AS DISCOVERED								**
	gettoken cmdstr mask : rest, parse("\")					// Split rest' into the command string and the syntax mask
						
	gettoken preopt rest : cmdstr, parse(",")				// Locate start of optionstring within cmdstr (it follows a comma)
	if substr("`rest'",1,1)=="," local rest = substr("`rest'",2,.)
	if strpos("`rest'",",")>0 {
		display as error "Only one options list is allowed with up to 15 varlists{txt}"
*               		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox stop "Only one options list is allowed with up to 15 varlists{txt}"
	}
	
	gettoken options postopt : rest, parse("||")			// That optstring ends either with a "||" or with the end of cmdstr
															// (if it ends with "||" those pipes must remain at start of 'postop')
	local multivarlst = "`preopt' `postopt'"				// It doesn't matter where `options' sit within `cmdstr'
															// (this code leaves us with complete `multivarlst' and `options') 
															// (Note that pipes left at start of 'postopt' now terminate 'preopt')
	

	
	
pause (0.2)
										// (0.2) Codeblock to extract the `prefixtype' argument and `multiCntxt' flag that preceed 
										//		 the parsing `mask' (see any calling `cmd' for details); discovers the option-name of
										//		 the first argument – an argument that will hold a varname or list of varnames that
										//		 might, if the user chooses, instead be held as a prefix to each varlist (varlist
										//		 prefixes can be different for each varlist wheras options cannot)
												 
	
	local mask = strtrim("`mask'")
	if substr("`mask'",1,1)=="\"  {
	    local mask = strtrim(substr("`mask'",2,.)) 			// Trim off the backslash that sits at the head of `mask'
	}
	gettoken prfxtyp mask : mask							// Get `prfxtyp' option+argument (all in 1 word) from head of mask
	gettoken istwrd mask : mask								// See if 1st word of remaining `mask' is a `multicntxt' flag
	local multiCntxt = ""									// By default assume this cmd does NOT take advantage of multi-contxts
	if "`istwrd'"=="multicntxt"  {							// First option has differnt names in differnt cmds, hence double-quotes
		local multiCntxt = "multiCntxt"						// Reset multiCntxt local if `multicntxt' option is present
	}														
	else  {													// Else 1st word is not "multicntxt"
		local mask = "`istwrd'" + "`mask'"					// So re-assemble mask by prepending whatever was in 1st word to rest
	}														//  of mask; but with "multicntxt" flag and leading "\" removed
	gettoken preparen postparen : mask, parse("(")			// Identify the option-name for that 1st option by parsing on "("
	local opt1 = lower("`preparen'")						// Deal with any capitalized initial chars in this option name
															// (leaves the lower case version of 1st option in 'opt1', needed below)
	local saveoptions = "`options' `prfxtyp'"				// Append 'prfxtyp' to 'options' so it can be parsed by syntax command
															// (along with user-supplied options)
	if substr("`saveoptions'",-1,1)=="\" {
	    local l = strlen("`saveoptions'")
		local saveoptions = substr("`saveoptions'",1,`l'-1)
	}														// Use `saveoptions' bedause `options' will be schlocked by next syntax
	
	
	
	
pause (1)	


										// (1) Process the options-list (found among the perhaps several varlists in codeblk 0.1)
										
	
	local keep = ""										// will hold 'opt1' from 0.2 plus contextvars itemname stackid if optd
	
	local options = "`saveoptions'"						// Retrieve `options' saved in codeblk 0.1
	
	if substr("`options'",1,1)==","  {					// If `options' (still) starts with ", " ...
		local options = strltrim(substr("`opts'",2,.))	// Trim off leading ",  " 
	}													// (Did not use `options' local as that gets overwritten by syntax cmd)
														// This code permits successive optlists to update active options
														// (experimantal code now redundant but retained pending future evolution)
	if "`options'"!=""  {								// If this varlist has any options appended ...							
	 
		local opts = "`options'"						
														// ('ifinwt' exprssns must be appended to first varlist, if more than one)
		local 0 = ",`opts' "  							// Named opts on following syntax cmd are common to all stackMe commands 		
														// (they supplement `mask' in `0' where syntax cmd expects to find them)
														// Initial `mask' (coded in the wrapper's calling `cmd' and pre-processed
														//  in codeblock 0 above) applies to all option-lists `in multioptlst'
															
*		***************									// (NEW and MOD in this syntax command anticipate future development)		***
		syntax , [`mask' NODiag EXTradiag REPlace NEW MOD NOCONtexts NOSTAcks ] /// 
/*	    **************/	  [ prfxtyp(string) * ]		  	// `mask' was establishd in calling `cmd' and preprocssd in codeblk (0.2)
														// `new' replaced both NEWoptions and NEWexpressions; `mod' was default		***



		if "``opt1''"!="" & "`prfxtyp'"=="var"  {		// If first option not empty and would be replaced by a var prfx, if optd
			local keepopt1 = "``opt1''"					// (was not derived from syntax but from end of codeblk 0.2)
		}
		
		if "`nodiag'"!=""  local limitdiag = 0			// One of the options in `mask' above
		if `limitdiag'==-1 local limitdiag = .			// Make that a very big number
		
		if ("`nocontexts'" != "") local contexvars = "" // Substitute a null string for any varlist found in `contextvars'

		if ("`nostacks'" != "")  local stackid = "" 	// Ditto for SMstkid 														***
		
		gettoken opt rest : opts, parse("(")			// Extract optname preceeding 1st open paren, else whole of word
														// NOTE: 'opt' and 'opts' are different locals
		
		if "`cmd'"=="gendummies"&"`opt'"=="prefix" { 	// (any remaining might be legacy option-names)
			display as error "NOTE: prefix option is is named 'stubprefix' in version 2. Exiting `cmd'." 
			window stopbox stop "Prefix option is named 'stubprefix' in version 2. Exiting command."	
		}												// (also, `opt' is named `opt1', saved at end of codeblk 0.2)

		if "`cmd'"=="gendist"  {
		   if "`respondent'"!="" & "`prefix'"!="selfplace"  {
		      display as error "Option 'respondent is option 'selfplace' in version 2. Exiting `cmd'{txt}"
		      window stopbox stop "Option 'respondent' is option 'selfplace' in version 2. Exiting command."
		   }
		   
		   if "`selfplace'"!=""  {
		   	  local keep = "`selfplace'"
			  capture confirm variable `keep'
			  if _rc {
		         display as error "Option 'selfplace' does not name an existing variable. Exiting `cmd'{txt}"
		         window stopbox stop "Option 'selfplace' does not name an existing variable. Exiting command."
			  }
		   }
			
		   if ("`mprefix'`pprefix'`dprefix'" != "")  {			// If any of these prefix options was used
			  if "`aprefix'"!="" {
			    display as error "Cannot use option aprefix along with any other prefix-naming option(s){txt}"
			    window stopbox stop "Cannot use option aprefix along with any other prefix-naming option(s)"
			  }				   // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   }

		} //endif `cmd'=="gendist"
		
		
		
		

		if "`contextvars'"!=""  {								// If contextvars are specified
		   capture unab list : `contextvars'					// (in which case, need variable(s) in `contextvars')
		   if _rc  {
			  display as error "Varlist for contextvars option must contain valid variable names. Exiting "`cmd'."{txt}"
*							    12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  window stopbox stop "Varlist for contextvars option must contain valid variable names. Exiting command."
		   }
		} //endif 'contextvars'!=""
		
		
		local keep = "`keep' `keepopt1' `contextvars' `itemname' `stackid'" // Keep opt1 contextvars itemname and stackid, if any
																// SMitem must also be kept if it is referenced
																// So will keep the var pointed to if it exists

		global limitdiag = `limitdiag'							// Provides access to `limitdiag' option for calling cmd if needed
 
	} //next 'varstubs'
	
	local lstwrd = word("`opts'", wordcount("`opts'"))
	local optionsP = subinword("`opts'","`lstwrd'","",1)		// Save 'opts' less last word of opts (the added 'prfxtyp' option)
																// (put in 'optionsP' to be passed to 'cmd'P)
															
	local keepoptvars = strtrim(stritrim("`keep'"))				// Each codeblock from here on will end with a list of vars to keep
	

	local savecontextvars = "`contextvars'"						// These vars lose their contents before the next time they are used
	local savestackid = "`stackid'"

	
	
	
	
pause (1.1)


	
										// (1.1) This codeblock extracts each varlst and pre-processes if/in/weight expressns for  
										//	   each varlst/stublst (leaving the varlist in 'anything' shorn of 'ifinwt' expressions) 
										//	   and those var/stub lists are appended in turn to a new 'multivarlst'
	
	
	local varstubs = "`multivarlst'"							// Put the 'multivarlst in local 'varstubs' (some vars may be stubs)
	if strpos("`varstubs'","||") & "`cmd'"=="genmeans"  {
		display as error "Command {bf:genmeans} does not process multiple varlists{txt}"
*               		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox stop "Command genmeans does not process multiple varlists"
	}
	
	local multivarlst = ""										// Then empty it to be refilled with var/stub lists shorn of ifinwt
	
	local lastvarlst = 0										// Will be reset =1 when final varlist is being processed
	
	local noweight = "noweight"									// Flag says no weight expression as yet for any varlist
	
	local keep = ""												// This will hold `ifvar' `keepwtv' SMitem S2item, if referenced

	while "`varstubs'" != ""  {									// Repeat loop while there is still another string  in 'varstubs'
	 
		gettoken anything varstubs : varstubs, parse("||")		// Put successive lsts of vars/stubs (all up to "||") in 'anything'
		
		if "`varstubs'"==""  local lastvarlst = 1				// Reset this switch when no more pipes follow final 'varstubs' 
		else local varstubs = substr(strtrim("`varstubs'"),3,.)	// Else remove those pipes from what is now the start of 'varstubs'
		
		local nvarlst = `nvarlst' + 1							// `nvarlst' from codeblk 0, line 58, counts n of var/stub lists

		local 0 = "`anything'"									// This is the varlist [if][in][weight] typed by the user
																// (placed in local `0' because that is what 'syntax' cmd expects)
																// (using Stata's 'syntax' commmand to extract them from  'varexp')
		***************	
		syntax anything [if][in][fw iw aw pw/], [`mask' NODiag EXTradiag REPlace NEW MOD NOCONtexts NOSTAcks * ] 
/*	    ***************/	  							  		// `mask' was set in calling `cmd' and preprocssd in codeblk (0.2)
																// (trailing "/" ensures that weight 'exp' does not start with "=")

		local ifin = "`if' `in'"								// Ensure 'if' and 'in' expressns occur only on first var/stub list
		if "`ifin'"!="" & `nvarlst'>1  {
			display as error "Only 'weight' expressions are allowed on varlists beyond the first; not if or in{txt}"
*               		  	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			window stopbox stop "Only 'weight' expression' are allowed on varlists beyond the first; not 'if' or 'in'"
		}
		
		if "`if'" != ""  {										// If not empty, calls for `if' when establishng the working dataset
			tempvar ifvar										// Create a temporary variable to indicate which obs will be kept
			gen `ifvar' = 0										// Don't know name(s) of vars in 'if' expression but can substitute 
			qui replace `ifvar' = 1 `if'						//  this indicator whose name is known
			local ifexp = "if `ifvar'"							// Local will be empty if none
		} //endif `if'
		
		if "`in'"!=""  {										// If not empty, calls for `in' when establishng the working dataset
			local inexp = "`in'" 								// Store in inexp
		} //endif `in'											// If "'inexp`nvl''"!="" code "`inexp`nvl''" in codeblock 6 below
										
		if "`weight'"!=""  {									// If a weight expression was appended to the current varlist
		   local noweight = ""									// Turn off 'noweight' flag; calls for full tracking across varlsts
		   tempvar wtvar`nvarlst'								// Don't know name of weight variable but can create a substitute
		   qui gen `wtvar`nvarlst'' = 1 * `exp'					//`wtvar' encodes the product of the wtvar with user-providd 'exp'	***
		   local wtvar`nvarlst' = "`wtvar`nvarlst''"			// Local `wtvar' holds name of weight var specific to each varlist
		   local wtexp`nvarlst' = "[`weight'=`wtvar`nvarlst'']" //`wtexp' holds the required weight expression for each varlist
		   while wordcount("`wtexplst'")<`nvarlst'-1  {			// While 'wtexplst' is missing any previous weight expressions..
		   	 local wtexplst = "`wtexplst' null"					//  pad 'wtexplst' with null strings for each missing word
		   }
		   local wtexplst = "`wtexplst' `wtexp`nvarlst''"		// Append current weight expressions to list for passing to `cmd'P
		   local keepwtv = "`keepwtv' `wtvar`nvarlst''"			// Append weightvar to list of variables to be kept in workng data
		} //endif 'weight'
		
		else  {													// Else there was no weight expression appended to this varlst
		   if "`noweight'"==""  {								// If there was a previous `wtexp' (so this is not first 'nvarlst')
			 while wordcount("`wtexplst'"<`nvarlst'  {			// While previous 'wtexp' expression was missing
			   local wtexplst = "`wtexplst' null"				//  pad the `wtexplst' with null strings for each missing word
			 }
		   } //endif `noweight'
*		   else  {												// Else this was no previous weight expression and still is none 
		} //endelse												// Ensures 'wtexplst' remains empty when passed to 'cmd'P

		local keepwtv = "`keep' `wtvar`nvarlst''"
   
		local multivarlst = "`multivarlst' `anything' ||"		// Here multivarlst is reconstructed without any 'ifinwt' expressns
																// (any such were removed by Stata's syntax command)
		if `lastvarlst'  continue, break						// If this was identified as the final list of vars or stubs,						
																// ('break' ensures next line to be executed follows "} next while")
		if "`weight'"!="" quietly drop `wtvar`nvarlst''
		
	} //next while												// Otherwise repeat the while loop to process next var/stub list
	
	
	local keepanything = subinstr("`multivarlst'","||","",.)	// trim away pipes (strings in codeblk 3)
																// List of vars/stubs will provide names of vars generatd by 'cmd's
																// 'keepanything' will be further pre-processed in codeblk 3
	local keep = "`keep' `ifvar' `keepwtv'"	 
	
	
	if substr("`multivarlst'",-2,.)=="||"  {
		local len = strlen(strtrim("`multivarlst'"))
		local multivarlst = substr(strtrim("`multivarlst'"),1,`len'-2)
	}															// Trim off any trailing pipes from 'multivarlst'
																

	if strpos("`multivarlst'", "SMitem")>0	{					// If user included SMitem in varlist
		local SMitem : char _dta[SMitem]						// Retrieve primary stack `itemname' (linkage variable)
		if "`SMitem'"!=""  {									// If `SMitem' points to a 1st stage linkage variable ...
			gen SMitem = `SMitem'								// Make a copy of the linkage var, named by the alias name
			local keep = "`keep' `SMitem'"						// Add the aliased variable to the list of vars to be kept
		}
		else  {													// AS YET NO USE MADE OF SMitem ??									***
			display as error "SMitem does not reference an existing variable"
*               		  	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			window stopbox stop "SMitem does not reference an existing variable"
		}	
	}

	if strpos("`multivarlst'", "S2item")>0	{					// If user included SMitem in varlist
		local S2item : char _dta[S2item]						// Retrieve secondary stack `itemname' (linkage variable)
		if "`S2item'"!=""  {									// If `thiS2item' points to a 2nd stage linkage variable ...
			gen S2item = `S2item'								// Make a copy of the linkage var, named by the alias name
			local keep = "`keep' `S2item'"						// Add the aliased variable to the list of vars to be kept
		}
		else {
			display as error "S2item does not reference an existing variable"
*               		  	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			window stopbox stop "S2item does not reference an existing variable"
		}
	}															// AS YET NO USE MADE OF S2item ??									***
			
										
	local keepifwtvars = strtrim("`keep'")
	
	
	
	
	
	
pause (2)



										// (2) Deal with special case of genstacks variable/stub list and options
										//	   (genstacks only has one varlist so need not be processed in codeblk 1)

	  
	
	if "`cmd'"=="genstacks" {								// If dataset is about to be stacked ...					

		local frstwrd = word("`multivarlst'",1)				//`multivarlst' from codeblk (0) reconstructed in codeblk (1.1)
		local test = real(substr("`frstwrd'",-1,1))			// See if final char of first word is numeric suffix
		local isStub = `test'==.							//`isStub' is true if result of conversion is missing

		if `isStub'  {										// If user named a stub, need list of implied vars to keep
															//  in working data
			local reshapeStubs = "`multivarlst'"			// Stata's reshape expects a list of stubs

*			******************
			varsImpliedByStubs `reshapeStubs'				// Call on appended program
*			******************

			local impliedVars = r(keepv)					// Implied by the stubs actually specified by user
			if strpos("`impliedvars'",".")>0  local impliedvars = subinstr("`impliedvars'", ".", "", .)

		} //endif `isStub'									// Eliminate any missing variable indicators from `keepv'

		else  {												// Otherwise `frstwrd' is a varname with numeric suffix
															// (suggesting that other items in `keep' are also varnames)
			 local keepv = "`multivarlst'"					// (command reshape will dianose an error if not so)
			
*			 ******************
			 stubsImpliedByVars, keepv(`keepv')				// Program (appended) generates list of stubnames
*			 ******************
				
			 local stublist = r(stubs)						// (one stubname per varlist in genstacks syntax 1)
*			
			 ******************
			 varsImpliedByStubs(`stublist')					// See if both varlists have same number of vars
			 ******************
			
			 local impliedVars = r(keepv)					// 'Implied' by the variables actually specified by user

			 local same : list impliedVars === keepv		// returns 1 in 'same' if 'implied' & 'keep' have same contents 
*		
			 if ! `same'  {
				
				display as error "Varlists don't match variables implied by their stubs. Use implied variables?{txt}"
*               		  		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
				capture window stopbox rusure "Stubs from varlists imply vars that don't match those varlists. Use implied vars?"

				if _rc !=0  {
					global exit = 2							// Exit with error if user says "no"; exit 2 is no restore before exit
					exit 1
				}
				noi display "Execution continues ..."

				if strpos("`stublist'",".")  local stublist = subinstr("`stublist'", ".", "", .) // Strip missng indicatrs & go on
															// Eliminate any missing variable indicators from `stublist'
				local reshapeStubs = "`stublist'"	

			  } //endif !`same'	

		} //endelse
															

		local nstubs = wordcount("`reshapeStubs'")			// Check that no stubnames already exist as variables
				
		forvalues i = 1/`nstubs'  {
			local var = word("`reshapeStubs'",`i')
			capture confirm variable `var'
			if _rc==0  {
				display as error "Variable with stubname `var' already exists"
				window stopbox stop "Variable with displayed stubname already exists"
			}
		} //next `i'
				

		if "`itemname'"!=""  {								// In genstacks any 'itemname' option names var to be kept, below
			capture confirm variable `itemname'				// (it provides a link from each stack to other battery items)
			if _rc !=0  {
				display as error "Option `itemname' does not name an existing variable"
				window stopbox stop "Option 'itemname' does not name an existing variable"
			}
		}													// Vars in 'varsImpliedByStubs' need to be kept in working data
															// (no SMstkid in unstacked data)
															// (only one varlst if cmd is genstacks)
															
		local keepimpliedvars = "`impliedVars' `itemname'"	// (But genstacks does need SMunit, etc., supplied next)													


															
											
											
											
											
pause (2.1)		
	
		
										// (2.1) For genstacks, additional vars are generally needed beyond those in `multivarlst'
										//		 (if 'cmd'=="genstacks" is still in effect)
										//		 Also need to see if genstacks is to doubly-stack the data or just singly stack.
										//		 Either way appropriate variables need to be created and flagged for keeping
															
		
		if "`nostacks'"!="" {
			display as error "'nostacks' cannot be optioned with command genstacks. Ignore and continue?{txt}"
			window stopbox rusure "'nostacks' cannot be optioned with command genstacks. Ignore and continue?"
*						 	   12345678901234567890123456789012345678901234567890123456789012345678901234567890	
			if _rc {
				global exit = 2
				exit 1
			}
			noi display "Execution continues ..."
			local nostacks = ""
		}													// This should never happen
		
		global dblystkd = ""								// Global used in `cmd'P must be empty if not doubly-stacked
		local dblystkd = ""
		local keepstackvars = ""							// As yet no SM variables to keep
					
		capture confirm variable SMstkid					// No SMstkid means data not yet stacked
		if _rc ==0  {									
			local stackid = "SMstkid"  						// Flag indicating whether that variable exists
			if `limitdiag'  {
				display as error  "NOTE: This dataset appears to be stacked (has SMstkid variable){txt}"
				display as error  "NOTE: Genstacks will try to doubly-stack these data; is that what you want?{txt}"				
*						 	   	   12345678901234567890123456789012345678901234567890123456789012345678901234567890	
				capture window stopbox rusure "Genstacks will try to doubly-stack these data; is that what you want?"
				if _rc  {
					global exit = 2
					exit 1
				}
				display as error "Execution continues..."
			} //endif
			
			local dblystkd = "dblystkd"	
			
		} //endif												

		else  {												// Else there is no SMstkid variable

			capture confirm variable SMunit					// SHOULD WE ALSO CHECK FOR HANGING SMnstks?					***
			if _rc==0  {
				display as error "NOTE: Variable SMunit should not already exist in unstacked data{txt}"
				window stopbox rusure "Variable SMunit should not already exist in unstacked data. Continue anyway?"
*						               12345678901234567890123456789012345678901234567890123456789012345678901234567890
				if _rc!=0  {
					global exit = 2
					exit 1
				}
				noi display "Execution continues ..."
			} 												// Will need these vars for stacking
			qui gen SMstkid = .								// Missing obs will be filled with values generated by reshape
			qui gen SMnstks = .								// Missing obs will be filled with values found after stacking
			gen SMunit = _n									// Above missing-filled vars created to avoid re-ordering
			label var SMunit "Sequential ID of observations that were units of analysis in the unstacked data"
*						      12345678901234567890123456789012345678901234567890123456789012345678901234567890
			local keepstackvars = "SMstkid SMnstks SMunit"	// NOTE these vars will be kept only if referenced by user		***
															// HOW WILL I ACHIEVE THAT??
		} //endelse
		

		
		if "`dblystkd'"!=""  {								// If data are to be duubly-stacked (SMstkid already exists)
											
			capture confirm variable S2stkid				// S2stkid should not already exist in unstacked data
			
			if _rc == 0  {
				display as error "Variable S2stkid should not already exist in data to be doubly-stackd. Continue?{txt}"
				window stopbox rusure "Variable S2unit should not already exist in data not doubly-stacked. Continue anyway?"
*						 		  12345678901234567890123456789012345678901234567890123456789012345678901234567890	
				if _rc!=0  {
					global exit = 2
					exit 1
				}
				noi display "Execution continues ..."
			}
			qui generate S2stkid = .						// Missing obs will be filled with values generated by reshape
			qui gen S2nstks = .								// Missing obs will be filled with values found after stacking
			generate S2unit = _n							// Missing-filled vars again created to avoid unknown error
			label var S2unit "Sequential ID of observations that were units of analysis in singly-stacked data"
*					          12345678901234567890123456789012345678901234567890123456789012345678901234567890		

			local keepstackvars = "`keepstackvars' S2stkid S2nstks S2unit"
															// NOTE these vars will be kept only if referenced by user		***
		}
		else {
*			if `limitdiag' display as error  "NOTE: This dataset appears to be stacked (has SMstkid variable){txt}"
															// Existing SMstkid in genstacks does not mean already stacked
		}
		
	}  //endif 'cmd'==genstacks
			
	
	else  {														// Not cmd genstacks

		if "`stackid'"==""  {									// If there is no SMstkid, the data are not stacked
			if "`cmd'"=="genplace" {
				 display as error "Command {bf:genplace} requires stacked data. Exiting `cmd'"
				 window stopbox stop "Command genplace requires stacked data. Exiting."
			} 
		} //endif												// SMstkid is included in workng data if referenced by user

		else  {													// Else have stackid
			capture confirm variable S2stkid					// So check if also have S2stkid
			if _rc==0  {
				local dblystkd = "dblystkd"
				if `limitdiag' displ as error "NOTE: This dataset appears to be doubly-stacked (has S2stkid variable){txt}"
*						 		               1234567890123456789012345678901234567890123456789012345678901234567890123
			}
			else {
				if `limitdiag' display as error  "NOTE: This dataset appears to be stacked (has SMstkid variable){txt}"
			}
			
		} //endelse
			
	} //endelse
	   

	global dblystkd = "`dblystkd'"								// Make copy in global accessible from elsewhere

	local keepstackvars = "`keepstackvars'"						// Filled before the 'else not genstacks' above	
		
							
	
	
 

pause (3)	

		
										// (3) Checks syntax of prefix var(lists) accumulats list of vars in each prefixlist
										//	   to keep in working data (varlist might be a namelist for genstacks).
										//	   Put 'opt1' into 'keep' if it is a variable
										

	local thismultivlst = "`multivarlst'"					// Don't want to schlock the 'multivarlst' local
	local theseprfxvars = ""								// Where prefix vars will be accumulated, varlist by varlist

	local isprfx = 0										// By default assume that any genyhats varlist has no prefix
	
	forvalues nvl = 1/`nvarlst'  {
		
	   gettoken varlst postpipes : thismultivlst,parse("||") // Put next varlist into 'varlst'
	   if "`postpipes'"!=""  local thismultivlst = strtrim(substr("`postpipes'",3,.))
	
	   gettoken precolon postcolon: varlst, parse(":") 		// See if varlist has a prefix indicator 

	   if "`postcolon'"!=""  {								// We know we found a colon when postcolon is not empty
	     local isprfx = 1									// Needed for genyhats; irrelevant elsewhere
	     gettoken preul postul : precolon, parse("_")		// If prefix is divided by underline this is yhats/dummies prefx
	     if "`postul'"!=""  {								// If there was a divided prefix
	        if "`cmd'"!="genyhats" &"`cmd'"!="gendummies" {	// If `cmd' is not genyhats or gendummies
	   	       display as error "Double-prefix is only allowed with 'genyhats' and 'gendummies' commands{txt}"
*                		  		 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		       window stopbox stop "Double-prefix is only allowed with 'genyhats' and 'gendummies' commands"
		    }
			
		    else  {											// Else `cmd' is genyhats or gendummies
		       local thisInd = "`preul'_"			 		// Save prefix string in thisInd (for 'thisIndicator")
			   local prfxvars = substr("`postul'",2,.)		// Strip preul, "_" & any blanks from start of prefix(list)
			   local keepanything = subinstr("`keepanything'","`preul'_","",.) // remove prfxs frm kept dta
		    }												// (for genyhats, position as prefix tells us prfxvar is depvar)

		 } //endif 'postul' 
		 
		 else  {											 // Else there was no genyhat-type double-prefix
															 // (but there was still a colon)
		     if "`prfxtyp'"=="var"  {   					 // Here dispose of prefix dependng on prefix type, var or other
			   capture unab prfxvars : `precolon'			 // `thisInd' will ultimately hold only prefix strings
			   if _rc>0  {									 // (`prfxvars' holds variables; `opt1' names corresponding optn)
				 display as error "Prefix symbol ':' needs preceeding varname(s); you named: `prfxvars' {txt}"
				 window stopbox stop "Prefix symbol ':' needs preceeding varname(s); spelling/capitalization error?" 
*                		  		      12345678901234567890123456789012345678901234567890123456789012345678901234567890
			   }											// Effectively this is an 'else keep prfxvars'
			   local theseprfxvars = "`theseprfxvars' `prfxvars'"

			 } //endif 'prefixtyp'	

			 else {												// Else prefix is a string; remove it from var/stublists
			 	local thisInd = "`precolon'"
				local keepanything = subinstr("`keepanything'", "`thisInd'", "", .)
			 }													
										
			 capture confirm variable ``opt1''				 	// See if there is a varname in first option
																// Note: need double-quotes to access var `opt1' points to
			 if _rc==0  local theseprfxvars = "`theseprfxvars' ``opt1''" 
																// If so, save it in 'theseprfxvars' as though it was a prfx
		 } //end else
							
																// geniimpute can have multiple prefix vars (other cmds not)
		if wordcount("`prfxvars'")>1 & "`cmd'"!="geniimpute"  {
			 display as error "`cmd' cannot have multiple 'prefix:' vars (only cmd geniimpute). Missing '||' ?{txt}"
			 window stopbox stop "command cannot have multiple 'prefix:' strings. Missing '||' ?"								
*                		  		12345678901234567890123456789012345678901234567890123456789012345678901234567890
		} //endif wordcount
																// Cannot have prefix that is included in varlist	  
		if strpos("`postcolon'","`prfxvars'")>0  & "`prfxtyp'"=="var"  { 
			 display as error "Prefix to varlist appears in list of indepvars{txt}"
			 window stopbox stop "'Prefix:' to varlist appears in list of indepvars" 
		}	
			
		if "`prfxvars'"!="" & "`cmd'"!="genyhats" & "`cmd'"!="gendummies"  {
															// Here deal with any conflicts arising from a new prefix option
			if "``opt1''"!=""  {							// Note double '' to establish whether `opt1' points to anything
				if `limitdiag' display as error "NOTE: Indicator prefix 'prfxvars:' replaces indicator option ``opt1''{txt}"
*                		  		  				 123456789012345678901234567890123456789012345678901234567890123456789012345
			} 												// NOTE THAT only for hats&dummies does prefix not replace `opt1'
															// (in 'genyhats' it repaces ydprerix) for univariate analyses)
		} //endif `prfxvars' 
					
	  } //endif `postcolon'!=""								// End of code interpreting prefix types
	
	} //next `nvl'	
	   	
	local prefixvars = "`theseprfxvars'"

	local keepprfxvars = "`theseprfxvars'"	
	
    local keepanything = stritrim(subinstr("`keepanything'",":"," ",.))	
															// Need spaces to replace colons; then trim extra spaces
	local varstubs = "`keepanything'"
	if "`cmd'"=="genstacks"  local keepstubs = ""			// Don't include list of varstubs in keptvars when stacking
															// (NOTE: here varstubs r vars from stubs; elsewhre var/stublst	***
	
	local keepvars = strtrim(stritrim(					   ///
				"`keepoptvars' `keepifwtvars' `keepimpliedvars' `keepstackvars' `keepprfxvars' `keepstubs' `origunit'"))

	
	
	
	
		


pause (4)

		
		
										// (4) Initialize ID variables needed for stacking and TO merge working data back 
										//	   into original data.
																


	capture erase `origdta'										// Before making any changes to data being processed ...
	capture drop `origunit'
	tempfile origdta											// Temporary file in which full dataset will be saved	
	tempvar origunit											// Temporary var inserted into every stackMe dataset, to enable
	gen `origunit' = _n											//  merge of newly created variables with original data
																// Equivalent to 'default' frame which, however, runs more slowly	

															
*	************
	quietly save `origdta'								    	// Will be merged with processed data after last call on `cmd'P
*	************												// (Changes to working data made below should be temporary)



	local temp = ""												// Name of file/frame with processed vars for first context
	local appendtemp = ""										// Names of files with processed vars for each subsequent contx
			
			
				
			
	
	
			
pause (5)



										// (5) Ensure all vars to be kept actually exist, remove any duplicates, check for 
										//     accidental duplication of existing vars. Here we deal with all kept vars,
										//	   from whatever varlist in the multivarlst set
	
	
	local keep = "`keepvars'"
	
	local keep = strltrim(subinstr("`keep'", ":", " ", .))	// Remove any colons that might have been in 'saveAnything'
	local keep = stritrim(subinstr("`keep'","||", " ", .))	// Remove any pipes ditto
	


*	*****************										// Check that all vars to be kept are actual vars
	capture unab keep : `keep'								// (stackMe does not support TS operators)
*	*****************										// (May include SMitem or S2item generated just above)
	
			
	local keepvars : list uniq keep							// Stata-provided macro function to delete duplicate vars

	
	if "`cmd'"=="gendist" {									// Commands should not create a prefixed-var that already exists

		foreach var of local keepanything  {				// Only vars to be used as stubs need be checked
			local pfx = "d_"
			if "`dprefix'"!="" local pfx = "`dprefix'"
			isnewvar `var', prefix(`pfx')						// Check to see if relevant prefixed var already exists
		} //next var										// (program isnewvar, below, asks for permission to replace)
	} //endif `cmd'=='gendist'
	
	
	if "`cmd'"=="gendummies" {								// Commands should not create a prefixed-var that already exists

		foreach var of local keepanything  {				// For gendummies two alternative varnames need to be checked
			if "`stubprefix'"!=""  {						// If user optioned a prefix for dummy varstub names
			   isnewvar `var', prefix(`stubprefix')			// Check to see if relevant prefixed var already exists
			}												// (program isnewvar, below, asks for permission to replace)
		} //next var										// If no stubprefix `var'name will become the prefix
	} //endif 'cmd'=='gendummies'							// (and created variables will have numeric suffixes)


	if "`cmd'"=="geniimpute"  {								// See comments above for explication

		foreach var of local keepanything  {
			local pfx = "i_"
			if "`iprefix'"!=""  local pfx = "iprefix"
			isnewvar `var', prefix(`pfx')					// Check to see if relevant prefixed var already exists
															// (program isnewvar, below, asks for permission to replace)
			local pfx = "mi_"
			if "`miprefix'"==""  local pfx = "miprefix"
			isnewvar `var', prefix(`pfx')					// Check to see if relevant prefixed var already exists
		} //next var										// (program isnewvar, below, asks for permission to replace)

	} //endif 'cmd'=='geniimpute'
		

	if "`cmd'"=="genyhats"  {

		foreach var of local keepanything  {
			if `isprfx'==0  {								// If this is NOT a multivariate procedure (`isprfx'==0)
				local pfx = "yi_"							// So created vars will be prefixed with 'yi_'
				if "`yiprefix'"!=""  local pfx = "yiprefix"
				isnewvar `var', prefix(`pfx')				// Check to see if relevant prefixed var already exists															// (program isnewvar, below, asks for permission to replace)
			}	
			else  {											// Else this multivariate varlist is prefixed with yd_ prfx
				local pfx = "yd_"							// User cannot option a different prefix
				isnewvar `var', prefix(`pfx')				// Check to see if relevant prefixed var already exists
			}
		} //next var										// (program isnewvar, below, asks for permission to replace)

	} //endif `cmd'=='genyhats'								// MAYBE SAME FOR GENDUMMIES??										***
		

	if $exit  {												// $exit>0 if prog isnewvar returned an error after any call
		global exit = 2										// Set $exit==2 if no need to restore data before exit
		exit 1	
	}
	
	local varstubs = "`keepanything'"
	if "`cmd'"=="genstacks" local varstubs = ""				// In genstacks don't want to keep stubs that are not yet vars
		
	local keepvars = strtrim(stritrim( ///
		"`keepoptvars' `keepifwtvars' `keepimpliedvars' `keepstackvars' `keepprfxvars' `varstubs' `origunit'"))

		
		
	
	
		
pause (5.1)



										// (5.1) Calculate '_mkcross' context enumeration
			
			
	tempvar _ctx_temp										// Variable will hold constant 1 if there is only one context
	tempvar _temp_ctx										// Variable that _mkcross will fill with values 1 to N of cntxts
	capture label drop lname								// In case error in prev stackMe command left this trailing
	local nocntxt = 1										// Flag indicates whether there are multiple contexts or not

	local contextvars = "`savecontextvars'"					// Saved in codeblck 1.1 to provede rescue when now needed
	local stackid = "`savestackid'"
	
	if "`contextvars'" != "" | "`stackid'" != ""  local nocntxt = 0  // Not nocntxt if either source yields multi-contxts
	if "`contextvars'" == "" & "`cmd'"=="genplace" local nocntxt = 1 // For genplace stacks don't produce separate contxts
																	 // (so nocntxt setting depends only on `contextvars')
	if `nocntxt'  {
		gen `_temp_ctx' = 1									// Don't need _mkcross to tell us no contextvars = no contxts
	} //endif
		
	else {													// else contextvars have been optioned
			
		if "`cmd'"!="genplace" local ctxvars = "`contextvars' `stackid'" // Unless genplace, supply whatever was optiond
		else  local ctxvars = "`contextvars'"				// For cmd `genplace', stackid must not be included 			 		***
			

			
*		****************
		quietly _mkcross `ctxvars', generate(`_temp_ctx') missing labelname(lname)										 //	 		***
*		****************									// (generally calls for each stack within context - see above)



	} // endelse 'nocntxt'
			
	local ctxvar = `_temp_ctx'							 	// _mkcross produces sequential IDs for selected contexts
															// (NOT TO BE CONFUSED with `ctxvars' used as arg for _mkcross)
	quietly sum `_temp_ctx'
	local nc = r(max)										// This is the number of contexts (`c'), used below and in `cmd'P		
				
	if $exit==2  exit 1										// $exit==2 does not require restoration of origdta

										// NOTE: Any exit before this point is a type-2 exit not needing data to be restored 
										//		 There should only be type-1 exits after this. These do require data restoration
										
				
															// Keep in working data only variables to be processed																													
*	**************
	keep `keepvars' `_temp_ctx'								// Keep only vars involved in generating desired results
*	**************											// (`keepvars' was `keep' with dups removed after 'unab', codeblk 5.
															// `origunit' is added to provide merging ID in orig & new data
															// TRY USING TEMPVAR (tho' had seeming problem merging on tempvar) 		***
					

					
					
					
					
pause (6)	



										// (6) Cycle thru each context in turn, preparing to repeatedly call `cmd'P by checking for
										//     context-specific errors		


	if `nc'==1  local multiCntxt = ""						 	  	  // If only 1 context after ifin, make like this was intended			

	if "`multiCntxt'"== ""  local nc = 1						 	  // If "`multiCntxt' is empty then there is only 1 context
																	  // (set in `cmd'.ado)
																	  
	if substr("`multivarlst'",-2,2)=="||" {			  				  // See if varlist ends with "||" (dk why this happens)
	   local len = strlen(strtrim("`multivarlst'"))
	   local multivarlst =substr(strtrim("`multivarlst'", 1,`len'-2)) // Strip those pipes if so
	}


	if `limitdiag'<0 local limitdiag = .						 	  // Overwrite `limitdiag' with big number if =-1

	  
	forvalues c = 1/`nc'  {									 	  	  // Cycle thru successive contexts (`c')
	
	    local lbl : label lname `c'							      	  // Get label associated by _mkcross with context `c'

	    preserve								 					  // Preserve the working data
		
*		   if "`extradiag'"!="" {								      // If extra diagnostics were optioned ... (badly placed if)

			if "`ifexp'"!="" local tempexp = "`ifexp' &"			  // If there IS an ifexp need to follow it with "&"
			else local tempexp = "if"								  // Else need the command "if" instead

			
			
*			************
			quietly keep `tempexp' `c'==`_temp_ctx' `inexp' 		  // keep is followed either by 'if' or by 'ifexp &'			
*			************
				

			   
			   if `limitdiag'>=`c' & "`cmd'"!="geniimpute" {		  // If `varmis'!="" note will be displayed after `cmd'P call																						 
																	  // (geniimpute produces its own diagnostics)
				   local vartest = "`keepanything'"
				   if "`cmd'"=="genstacks" local vartest = "`keepimpliedvars'" 
				   local varmis = ""								  // Will be list of vars that are all-missing in this context
				   local vartest = subinstr("`vartest'","||"," ",.)   // Remove all "||", replacing with " "
				   local vartest = subinstr("`vartest'",":", " ",.)   // Remove all ":", ditto
				   if "`opt1'"!="" & "`prfxtyp'"!="var" local vartest = subinstr("`vartest'","``opt1''","",.) // Remove any 'opt1' 
				   unab vartest : `vartest'							  //  prefix strings from list of vars being tested

				   local test : list uniq vartest					  // Strip any duplicates of vars in vartest
				   local nvars = wordcount("`test'")
				   scalar minN = .									  // (a big number)
				   scalar maxN = -999999

				   foreach var of local test  {					  	  // For each var in 'vartest'
				   
  					  capture qui count if  ! missing(`var')
					  if _rc!=0  {									  // If attempt leads to error
					  	 local varmis = "`varmis' `varmis`var''"	  // Add offending var to list of all-missing vars
					  }
					  else {										  // If no valid cases
					  	 if r(N)==0  {								  // Add offending var to same list
					  	    local varmis = "`varmis' `varmis`var''"   // If no obs, add to 'varmis' list 
					     }
				      } //endelse
					  
					  local i = 0
					  local noobsvarlst =""
					  
					  while `i'<`nvars'  {
						local i = `i' + 1
						local var = word("`test'",`i')
						tempvar mis`var'
						qui gen `mis`var'' = missing(`var')			  // Code mis'var' =0, or =1 if missing
						qui capture count if ! `mis`var''			  // Unless errer, yields r(N)==0 if var does not exist
						local rc = _rc
if `rc' display `rc'
					    if `rc' & `rc'!=2000  {						  // If non-zero return code which is not 'no obs'
							global exit = 2
							continue, break
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
				   
				   if !$exit  {
				      if `rc'!=0 & `rc'!=2000 {						// If there was a diffrnt error in any 'count' command
						 local lbl : label lname `c'				// Get the context id
					     display as error "Stata has flagged error `re' in context `lbl'{txt}" _continue
error `rc'
					     global exit = 1							// Set flag for wrapper to exit after restoring origdata
				      }
				   
				   } //endif ! $exit
			 
			   } //endif 'limitdiag'
				 
*		   } //endif `extradiag'
	   

		   if  ! $exit  {

	         forvalues nvl = 1/`nvarlst'  {							  // HERE ENSURE WT EXPRESSIONS GIVE VALID RESULTS
	   				 
		       if "`wtexp"!=""  {									  // Now check if weight var is not missing in this context

			     local wtexpw = word("`wtexp'",`nvl')				  // Obtaining local name from list overcomes a Stata naming problem
			     capture sum `origunit' `wtexp', meanonly			  // Weight the only var known to exist in a call on `'mean'

			     if _rc  {											  // An error can only be due to the 'weight' expression

				   if _rc==2000  display as error "Stata reports 'no obs' error; perhaps weight var is missing in context `lbl' ?{txt}"
									            //12345678901234567890123456789012345678901234567890123456789012345678901234567890 
				   else  {
					  local l = _rc
					  display as error "Stata reports error `l' in context `lbl'{txt}"
				   }
error `l'
			       global exit = 1									  // Tells wrapper to exit after restoring origdata
				   continue, break									  // Must restore origdta before exiting

			     } //endif _rc

		       } //endif `wtexpw'
			 
		     } //next 'nvl'
		   
		   } //endif $exit
			
		   if "`cmd'"=="genstacks'" local  multivarlst = "`stublist'" // Genstacks processes stubnames, not varnames
		   global multivarlst = "`multivarlst'"					 	  // Global version accessible to calling prog in `cmd'.ado  
			   
			
			
			
			
			   
pause (7)

										// (7) Issue call to `cmd'P with appropriate arguments; catch any `cmd'P errors; display 
										//	   optioned context-specific diagnostics
set tracedepth 4						//	   NOTE that 'forvalues `c'=' remains in effect



																		
		   
		   if ! $exit  {												// So long as an error was not flagged just above,..
				
				
				 
*				 **************				     	 					// Most `cmd'P programs must be aware of lname for ctxvars   ***
				`cmd'P `multivarlst', `optionsP' nc(`nc') c(`c') nvarlst(`nvarlst') wtexplst(`wtexplst')
*				 **************											 

	
	
				if ! $exit  {											// So long as no error flagged in called program
					
				   if `limitdiag'>=`c'  {								// `c' is updated for each different stack & context
								   
						
					  local numobs = _N
				   	
					  local contextlabel : label lname `c'				// Get label for this combination of contexts
					  
					  local contextlabel = "Context `contextlabel'"		// Below we expand what will be displayed
																		// (depending on context)
					  if `c'==1 noisily display "{bf} "
					  
					  local newline = "_newline"
					  if "`cmd'"=="genstacks" local newline = ""
					  
					  if "`multiCntxt'"=="" {
					  	 local contextlabel = "{bf}This dataset"
						 noisily display "{bf}   `contextlabel' has `numobs' cases{txt}"
					  }
					  
					  if "cmd'"=="genstacks"  local contextlabel = "This dataset now"

					  if "`multiCntxt'"!="" & "`cmd'"!="geniimpute" {	// Geniimpute has its own diagnostics
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
					  local minN = minN									// Make local copy of scalar minN
				      local maxN = maxN									// Ditto for maxN
				      local lbl : label lname `c'
					  local newline = "_newline"
					  if "`cmd'"=="genstacks" local newline = ""
				      if "`multiCntxt'"!="" & "`cmd'"!="geniimpute" noisily display /// geniimpute displays its own diagnostics
										"{bf}`other'in context `lbl' have between `minN' and `maxN' valid obs{txt}" _newline
						 
				   } //endif 'limitdiag'
				   
				} //endif ! $exit

	

		   } //endif ! $exit											// From now on, exits could have been flagged in cmd'P prog
		   
		   
						
																		
		   if $exit  {											 		// Else error exit from `cmd'P, restore origdata then exit
				  capture restore										// Not sure what can go wrong but evidently something did
				  quietly use `origdta', clear
				  exit 1
		   } 
				     
		   if `limitdiag'>=`c' & "`varmis'"!="" {						// `varmis' got its value before call on `cmd'P

			   if "`extradiag'"!=""  {
					  local errtxt = ""
					  local nwrds = wordcount("`varmis'")
					  local word1 = word("`varmis'", 1)
					  if `nwrds'>2  local word2 = word("`varmis'", 2)
					  local wordl = word("`varmis'", -1)				// Last word is numbered -1
					  if `nwrds'>2  local errtxt = "`word2'...`wordl'"
					  if `nwrds'==2 local errtxt = "`word1' `wordl'"
				   	  if `nc'>1  display as error "{bf}NOTE: No observations for var(s) `word1' `errtxt' in context `lbl'{txt}"
					  if `nc'==1 display as error "{bf}NOTE: No observations for var(s) `word1' `errtxt'{txt}"
			   } //endif extradiag										// `limit' is from `limitdiag' before above "forvalues `c'="

		    } //endif 'limitdiag'>=`c'
																	
			
			
			
			tempfile i_`c'
			quietly save `i_`c''										// Save results for each context in tempfile named "i_`c'"	
			if `c'==1 local temp = "`i_`c''"							// If this is first context, save the fullname in 'temp'
			
			if `c'==1  {												// If this is first context ...
				local fullname = c(filename)							// Path+name of datafile most recently used/saved by Stata cmd
				local nameloc = strrpos("`fullname'","`c(dirsep)'") + 1	// Position of first char following final "/" or "\" of dirpath
				local savpath = substr("`fullname'",1,`nameloc'-1)		// Path to final dirsep should be same for all successive files
				local appendlst = ""									// (include dirsep in path)
		    }															// appendlst is list of trailing filenames (following dirsep)
			else  {														// For later contexts, each in turn
				local fullname = c(filename)							// Get the fullname for file, saved before "if `c'==1" above
				local thisname = substr("`fullname'",`nameloc',.)		// Trailing name of file to hold data generatd for this context
				local appendlst = "`appendlst' " + substr("`fullname'",`nameloc',.)
			}															// (first file at front of list so never need count to end)
																		// ('trailing' means "following dirsep"; fullname inclds path )
		restore															// Restore full dataset from which to extract next context
																		// (if already restored, this will have resulted in early exit)
	   
	  if $exit continue, break											// Should not occur: any errors should have led to earlier exit
	   
	   
	  
	} //next context (`c')

	

	

	
pause (8)	
	

										// (8) After processing last contxt (codeblk 6), post-procss generatd data for merging with 
										//	   original (saved) data
	
*	if `more' {															// REDUNDANT OPENING AND CLOSING LINES for this codeblk		***
										
	  if "`multiCntxt'"!= ""  {											// If there ARE multi-contexts (local is not empty) ...
																		// Collect up & append files saved for each contxt in codeblk (7)
																		// (If there was only one context then just one was saved)
		 preserve

			quietly use `temp', clear									// Tempfile in which the first context was saved in codeblock (7)

			local napp = wordcount("`appendlst'")						// N of contexts, beyond the first, produced tempfiles
			forvalues i = 1/`napp'  {				
				local a = word("`appendlst'",`i')						// Get trailing name for each file to be appended
				quietly append using "`savpath'`c(dirsep)'`a'", nonotes nolabel
				erase `savpath'`c(dirsep)'`a'							// (full name of file to be append starts with path and dirsep)	
			} //next 'i'
																			
			quietly save `temp', replace								// File `temp' now contains all new variables from `cmd'P
		
		 restore
		
	
	  } //endif `multiCntxt'
	  
	  else  quietly use `temp', clear									// Happens for 'cmd's that treat all contexts as one
	
*  } //endif more														//REDUNDANT OPENING AND CLOSING LINES for this codeblk
	
	


	
pause (9)
	

	
										// (9) Deal with temp renaming; merge new vars, created in `cmd'P, with original data
										

	quietly use `origdta', clear								// Retrieve original data to merge with new vars from `cmd'P
	  		
	local var1 = word("$multivarlst",1)							// ENSURE $multivarlst ALWAYS STARTS W multivarlst VARS				***
	
	if "`cmd'"=="gendist"  {
		capture confirm variable d_`var1'						// In case origdta already contains d_-prefixed var(s)...
		if _rc==0  {
			capture rename (d_*) (D_*)
			capture rename (m_* p_*) (M_* P_*)					// Allows for possibility that opt aprefix will alter m_* & p_*
		}
	}
	if "`cmd'"=="geniimpute" {
		capture confirm variable i_`var1'
		if _rc==0  capture rename (i_*) (I_*)					// This ensures previous versions of prefix vars survive merging 
	}
	
	if "`cmd'"=="genyhats"   {
		capture confirm variable yi_`var1'	  					
	    if _rc==0  capture rename (yi_*) (YI_*)					
		capture confirm variable yd_`var1'
		if _rc==0  capture rename (yd_*) (YD_*)
	}


	  
	quietly merge 1:m `origunit' using `temp', nogen update replace
															   // Here the full temp file is merged back into `origdta'
				

				
	capture erase `origdta'									   // Erase tempfile and drop origunit
	capture erase `temp'
	capture drop `origunit'

	
*	capture label drop lname								   // Name must be avaliable for next call on _mkcross above
	

	
end //stackmeWrapper





**************************************************** SUBROUTINES **********************************************************





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

set trace on
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





capture program drop isnewvar									// Now called from wrapper (NO LONGER CALLED FROM gendist in VERSION 2)

program isnewvar
	version 9.0
	syntax varlist, prefix(name)
	
	if "`name'"=="null" local prefix = ""
	
	capture confirm variable `prefix'`varlist' 				// Actually just one varname
	if _rc==0  {
		display as error "`prefix'-prefixd `varlist' already exists; replace?{txt}"
		capture window stopbox rusure "Displayed prefixed variable already exists; replace?"
		if _rc != 0  {
			global exit = 2									// If not 'ok'
			exit 1
		}
		else drop `prefix'`varlist'
	}
	
end //isnewvar




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


