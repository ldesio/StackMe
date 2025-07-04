
capture program drop genplaceP		// This program is called for each context after getting stack means per context

program define genplaceP			// Called from stackmeWrapper; calls SMpolarizIndex
							
												
*! genplaceP version 2 for Stata version 9.0 (8/25/23 by MNF) processes multi-varlists prepared by stackmeWrapper. In 
*! the 2024 version of stackMe 2.0, genplace has an experimental structure that, if successful, will be progressively 
*! adopted by other stackMe commands. In this structure each call on `cmd'P is preceeded by two preparatory calls to 
*! new programs named `cmd'N and `cmd'O (N and O because these are the two letters in the alphabet that come before P).
*! `cmd'N contains what had been `cmd'P codeblocks that are preparitary to the first call on `cmd'P; `cmd'N contains
*! what had been `cmd'P codeblocks that are processed for each context separately, but that do not generate new data.
*! Code contained in `cmd'P codeblocks are, for genplaceP right now and for other commands in future releases, restric-
*! ted to codeblocks that generate generate or replace each variable in turn, one call on `cmd'P per variable. For most 
*! stackMe commands this reduces by one (for some commands it reduces, by two) the number of program calls that must 
*! preceed the final loop that processes each varlist in the multivarlist set of varlists. The loop itself is now init-
*! tiated in stackmeWrapper as the last action prior to the call on `cmd'P. 
*!    The new structure permits the number of stacks and the range of each variable to be standardized across contexts by
*! being based on features of the dataset as a whole rather that on features of each context, as in the current version
*! for certain commands.
*!
*! The mechanics employed to obtain a mean value across stacks (the value that 'places' those stacks) seems perhaps a bit 
*! clumsy: if twostep is optioned we make an optional 1st call (to genplaceP1) when we get mean values for each stack 
*! (pm_stckvar); then on a second call (to genplaceP2) we do the actual placements of those stacks or the indicator var.
*! The P1 program currently uses 'if' statements when deriving weighted means by stack; should explore frame alternatives.


global errloc "genplaceP(0)"

										// (0) genplaceP2 version 2 preliminaries (MOVED TO genplaceO)
	version 9.0
	
*****************
capture noisily {									// Error in following codeblocks will be processed after corresponding "}"
*****************
	
	syntax anything , [ CWEight(varname) INDicator(varname) MPRefix(string) PPRefix(string) IPRefix(string) ]			///
					  [ lbl(string) CALl(string) LIMitdiag(integer -1) NOPLUgall TWOstep EXTradiag WTPrefixvars ]		///
				      [ ctxvar(string) c(integer 1) nc(integer 1) nvarlst(integer 1) wtexplst(string) WTPrefixvars * ]
	


	
	if `limitdiag'==-1  local limitdiag = .						// Default unlimited diagnostcs optioned: make it big nmbr
	

global errloc "genplaceP(1)"	
	
											// (1) Cycle thru all varlists included in this call on `cmd'P
										

	forvalues nvl = 1/`nvarlst'  {								// Cycle thru each varlist in the multivarlst for `cmd'P

	  if "`wtexplst'"!="" local weight=word("`wtexplst'",`nvl') // Re-create the weight string passed from wrapper
	  if "`weight'"=="null" local weight = ""					// (this weight expression is used only for 1st step)
	  if "`weight'"!="" local weight = subinstr("`weight'","$"," ",.) // Replace all "$" (there to ensure word has no " ")

	  gettoken prepipes postpipes: varlist, parse("||")			//`postpipes' then starts with "||" or is empty at end of cmd
	  if "`postpipes'"==""  local postpipes = "`varlist'"
		 				
	  gettoken precolon postcolon: prepipes, parse(":")			// See if varlist starts with indicator prefix 
	  
/*	  gettoken preul postul : precolon, parse("_")				// COMMENTRD OUT 'cos DONT EXPECT PRE-UNDERLINE STRING
		if "`postul'" != ""  {
			local ydprefix = "`preul'"
			local dvar = strltrim(substr("`postul'",2,.)) 		// Trim off the leading "_"
		}
		else  {										  			// Else precolon contains only the depvarname
			local dvar = "`precolon'"					  		// And get prefix from option ydprefix
		}
*/																// `precolon' gets all of varlist up to ":" or to end of string
	  if "`postcolon'"!=""  {									// If not empty we have a prefix string
	  
		 if "`wrprefixvars'"=="" local indicator = "`precolon'" // (list of) indicator(s)
		 else  local cweight = "`precolon'"						// (List of) weighting variable(s)
		
		 local varlist = strltrim(substr("`postcolon'",2,.)) 	// strip off the leading ":" and any following blanks
			
 	  } //endif `postcolon'
		 
	  else  local varlist = "`prepipes'"						// No colon so prepipes has indepvars, ending with pipes or not
	  
	  local len = strpos("`varlist'","||") - 1					// Get length of varlist, terminated by "||"
	  
	  if `len'>0  local varlist = substr("`varlist'",1,`len')	// Strip any "||" from end of varlist
																// NEED WRAPPER TO CHECK THAT indicator IS VALUED ONLY 0 OR 1.	***
	
	} //next 'nvl' 
	
	
	

global errloc "genplaceP(2)"	

										// (2) Deal with possible `call' on SM subroutine
										

	if "`call'"!=""  {										// Retrieve genplace varlist from global, put there by genplaceO

		gettoken cmd rest : call, bind						// Bind expressions within paren even if not parsed on 
															// 1st word goes in `cmd', rest of 'call' goes in rest. If rest
		if substr("`rest'",1,1)==","  {						//  starts with comma it is an optionlist; otherwise positnl args
		   `cmd'`rest'										// Invoke `cmd' with options (comma stays in place)
		}													// Else no comma so arguments are positional
		else local cmd = "`2' `3' `4' `5'"					// Positional args are in `2' to `5' if comma is not in 2
		
	} //endif 'call'
										// NEED TO CONSIDER HOW THIS CODE RELATES TO THE REST OF THIS COMMAND. SHOULD IT MAYBE
										// COME FIRST? DOES IT USE THE INPUT/OUTPUT VARLIST(S) AS IT CHOOSES? THE USER OF SUCH
										// A PROGRAM WOULD OF COURSE BE ABLE TO DECIDE WHAT TO CALCULATE BEFORE THE CALL AND 
										// WHAT VARS TO GET THE CALLED PROGRAM TO GENERATE. MAYBE NEED TO SUPPRESS ANY OUTPUT
										// OTHER THAN WHAT IS GENERATED BY THE CALLED PROGRAM.									***

		
	// END OF CODE FOR CURRENT CONTEXT						// `stackmeWrapper' will collect up results by context
	
															// STILL MAY NEED CODE IN genplace CALLER TO FINISH UP ?
end //genplaceP







*************************************************** SUBPROGRAMS *****************************************************


capture program drop SMpolarizIndex


program define SMpolarizIndex			  	// Name of program called by genplace (rest of command line is
                                          	//  processed by the 'args' line that follows)

*! This program benefits from being able to access stacked observations (using egen) and vars (using gen)

global errloc "SMpolarIndex(0)"
		

   args opts                             	// Establishes the arguments used when invoking this `cmd'
                                          	// Next line refers to (global) varlist (counterpart to local)
   gettoken vars wt:(global)varlist, p("[") // Split varlist from appended weight expression (the global
                                            //  varlist was supplied by genplace); the weight expression
                                            //  will be needed by some users; the ', p("[")' suffix 
                                            //  provides a parsing character that replaces the default
                                            //  space used earlier to define word boundaries)
   local prfx = word("`opts'",1)            // Get what we need from the generic `opts' string
                                            // (for this `cmd', we need prefix string and weight var
		
   tempvar wtlr sumwt meanwtlr summeanwtlr devlr devlrsq wtdevlrsq
	
   foreach var of varlist vars {            // Cycle thru each `lrp' in the genplace varlist
										    // (varlist holds left-right placements of each party)
	  gen `wtlr'   = wt * var			    // Weighted l-r position of this party		
	  egen `sumwt'  = total(wt)				// Sum of weights for all parties in current context								
	  gen `meanwtlr' = `wtlr' / `sumwt'		// Mean of vote-weighted l/r positions for all parties 
	  egen `summeanwtlr' = total(`meanwtlr') if lr<. // Sum of meanwtlr – only for non-missing lr
	  gen `devlr' = `j'lr - `summeanwtlr'	// Deviation of party l-r position from mean l-r position			
	  gen `devlrsq' = (`devlr'/5)^2			// Squared normalizd l-r deviatns of pty from mean l/r for system	
	  gen `wtdevlrsq' = wt`wt' * `devlrsq'	// Weighted squared deviations (NOTE Dalton weights only by votes)	
	  egen sumwtdevlrsq = total(`wtdevlrsq') if lr<. // Sum of vote-weighted squared deviations–only non-missing
	  gen  `po_'`var' = sqrt(sumwtdevlrsq)	// Assign each result to successive (now "po_"-prefxd) vars
                                            // (separately for each combination of stack & context;
   } //next `var'                           //  a service provided automatically by stackMe according
                                            //  to user-supplied options for the genplace command)



	local skipcapture = "skip"										// No errors if exit above codeblocks at this point 

****************
} // end capture													// End of codeblocks where errors will be captured
****************

if _rc & "`skipcapture'"==""  {

												// Error handling for errors in above codeblocks comes here
	if _rc  errexit  "Stata flagged likely program error"


} //endif _rc &'skipcapture



										 	// Additional details are in the SMpolarIndex help file
                                            // The full called program is in the SMpolarizindex.ado file that follows 
                                            //  included in the 'genplace.ado' file.
end genplaceP 
									

******************************************** END SUBPROGRAMS *******************************************************

******************************************* SUBPROGRAMS *****************************************************


capture program drop SMpolarizIndex


program define SMpolarizIndex			  	// Name of program called by genplace (rest of command line is
                                          	//  processed by the 'args' line that follows)

*! This program benefits from being able to access stacked observations (using egen) and vars (using gen)

global errloc "SMpolarIndex(0)"
		

   args opts                             	// Establishes the arguments used when invoking this `cmd'
                                          	// Next line refers to (global) varlist (counterpart to local)
   gettoken vars wt:(global)varlist, p("[") // Split varlist from appended weight expression (the global
                                            //  varlist was supplied by genplace); the weight expression
                                            //  will be needed by some users; the ', p("[")' suffix 
                                            //  provides a parsing character that replaces the default
                                            //  space used earlier to define word boundaries)
   local prfx = word("`opts'",1)            // Get what we need from the generic `opts' string
                                            // (for this `cmd', we need prefix string and weight var
		
   tempvar wtlr sumwt meanwtlr summeanwtlr devlr devlrsq wtdevlrsq
	
   foreach var of varlist vars {            // Cycle thru each `lrp' in the genplace varlist
										    // (varlist holds left-right placements of each party)
	  gen `wtlr'   = wt * var			    // Weighted l-r position of this party		
	  egen `sumwt'  = total(wt)				// Sum of weights for all parties in current context								
	  gen `meanwtlr' = `wtlr' / `sumwt'		// Mean of vote-weighted l/r positions for all parties 
	  egen `summeanwtlr' = total(`meanwtlr') if lr<. // Sum of meanwtlr – only for non-missing lr
	  gen `devlr' = `j'lr - `summeanwtlr'	// Deviation of party l-r position from mean l-r position			
	  gen `devlrsq' = (`devlr'/5)^2			// Squared normalizd l-r deviatns of pty from mean l/r for system	
	  gen `wtdevlrsq' = wt`wt' * `devlrsq'	// Weighted squared deviations (NOTE Dalton weights only by votes)	
	  egen sumwtdevlrsq = total(`wtdevlrsq') if lr<. // Sum of vote-weighted squared deviations–only non-missing
	  gen  `po_'`var' = sqrt(sumwtdevlrsq)	// Assign each result to successive (now "po_"-prefxd) vars
                                            // (separately for each combination of stack & context;
   } //next `var'                           //  a service provided automatically by stackMe according
                                            //  to user-supplied options for the genplace command)

										 	// Additional details are in the SMpolarIndex help file
                                            // The full program is in the SMpolarizindex.ado file, 
                                            //  included in the 'genplace.ado' file.
end SMpolarizIndex 
									
**************************************** END OF SUBPROGRAMS ********************************************************
