
capture program drop genyhatsP					// Originally `genyhats', in Version 2 is called by `stackmeWrapper'

program define genyhatsP				
												// In v2 stackmeWrapper extracts working data before calling `cmd'P, afterwards 
												// merging the results back into the origial dataset
*set trace off
  
*! gendyhatsP version 2 for Stata version 9.0 (2/23/23 by Mark) has options cumulating as extra varlists are processed 
*! Minor tweaks Nov'24 to handle revised weighting strategy.

	// This is a rewrite of the version 1.5 genyhats (the version that processed multiple varlists, using byable code), 
	// renamed genyhatsP to make it callable from the version 2.0 stackMe wrapper (itself called from genyhats.ado).
	//    The stackmeWrapper calls genyhatsP once for each data context. It has added sevaral options tp the original
	// call that transmit information acquired by the wrapper that was previously supplied within this program. Option 
	// `extradiag' is now a standard stackMe option determining the verbosity of the output. Option `quietly' replaces 
	// the previous `outmode' local governing this verbosityt. Option `prefix' tells genyhatsP whether the `opt1' 
	// processed by the wrapper was supplied as a prefix to the depvarlist rather than as an option.
	//    CRITICALLY, the presence or absence of a prefix to the depvarlist determines whether yhats are produced
	// by bivariate or multivariate analyses (multivariate if the depvar is supplemented by the prefix).
	

																// genyhats-specific lines of code are suffixed with "**"
	
	version 16.1							// (0) genyhatsP version 2 preliminaries

*****************
capture noisily {												// introduces codeblocks within which any error will be captured 
*****************
												//(will be handled after the close capture brace
	syntax anything(id="varlist") [if][in][aw fw iw pw],[DEPvarname(varname) CONtextvars(varlist) ITEmname(varname) LOGit]  ///
	[ REPlace prfx(string) ADJust(string) EFFects(string) EFOrmat(string) limitdiag(integer -1) EXTradiag NODIAg ]			///
	[ NOCONtexts NOSTAcks nvarlst(integer 1) ctxvar(string) nc(integer 0) c(integer 0) wtexplst(string) * ] 
	
																// Wrapper adds optns following limitdiag
																// NOTE THAT prfx and `isprfx' are absent 'cos redundant		**
	
global errloc "genyh(1)"
	

	
											// (1) deal with options (these are the same for all varlists in set)
	
	local dvar = "`depvarname'"	 								// DEFAULT depvar for this (group of) varlist(s)
	local isprfx = ""											// By default there is no prefix, so not a multivariate analysis
	
	if (`limitdiag' == -1)  local limitdiag = .					// Make that a very large number
	if (`limitdiag' == 0)	local quietly = "quietly"
	if ("`extradiag'"!="" & "`limitdiag'"=="0") local limitdiag = .
	
	
		
																// WEIGHT IS APPLIED SEPARATELY FOR EACH nvarlst, below
	if "`adjust'"!=""  {
	   local cen = substr("`adjust'",1,3)						// Require only 1st 3 chars of keyword							***
	   foreach str in "mea con no"  {
		  if "`cen'"!="`str'"  continue							// If not matched continue with next str
		  local `cen' = "`str'"				
		  continue, break										// Break out of loop if found a match
	   }	
	} //endif
	else  local cen = "null"									// Seemingly need to initialize this local even if empty
			
	if `c'==1  {
			
	  if (`limitdiag'!=0 & `c'==1) { 							// display for first context if optioned
		local contextlabel : label lname `c'					// Retrieve the label for this context built by _mkcross		**
		noisily display "Y-hats will be separately generated by context (and stack)" _continue
		if "`extradiag'"!="" noisily display "(starting with {result:`contextlabel'})" _newline
	  }
	  else display " " _newline
	  
	} //endif `c'==1
																// All of the above is overhead repeatd for each `cmd'P 

																
global errloc "genyh(2)"

										
											// (2) HERE STARTS PROCESSING OF CURRENT CONTEXT . . .
											
			
	  quietly count 	
	  local numobs = r(N)										// N of observations in this context
			
			
	  forvalues nvl = 1/`nvarlst'  {						 
																// (any prefix is in `depvarname' & 'dvar')											
*		 gettoken prepipes postpipes: anything, parse("||")		//`postpipes' then starts with "||" or is empty at end of cmd
																// (COMMENTED OUT BECAUSE REPLACED BY VARS STORED IN SCALARS)
		 if "`wtexplst'" !=""  {
		 	local wt=word("`wtexplst'",`nvl') 					// Unpack the weight directive, if present
			if "`wt'"=="null"  local wtexp = ""
			else  local wtexp = subinstr("`wtexpw'","$"," ",.)	// Replace all "$" with " "
		 }														// ("$" replaced " " in wrapper so each nvl would fill a word)
		 else local wtexp = ""									// Else send an empty string to program predcent (below)
		 
/*																// COMMENTED OUT & REPLACED BY VARS STORED IN SCALAR STRINGS
		 gettoken precolon postcolon: prepipes, parse(":")		// See if varlist starts with indicator prefix 
																// `precolon' gets all of varlist up to ":" or to end of string
		 if "`postcolon'"!=""  {								// If not empty we have a prefix string
			gettoken preul postul : precolon, parse("_")
			if "`postul'" != ""  {
				local dprefix = "`preul'"
				local dvar = strltrim(substr("`postul'",2,.)) 	// Trim off the leading "_"
			}
			else  {										  		// Else precolon contains only the depvarname
				local dvar = "`precolon'"					  	// And get prefix from option ydprefix
			}
										
			local isprfx = "isprfx"						 		// Set `isprfx' flag, then	...	
			local indepvars =strtrim(substr("`postcolon'",2,.)) // strip off the leading ":" and any following blanks
			
 		 } //endif `postcolon'
		 
		 else  local indepvars = "`prepipes'"					// No colon so prepipes has indepvars, ending with pipes or not
*/
		 local isprfx = ""										// Assume multiple bivariate analyses by default
		 
		 if PRFXVARS`nvl'!="" & PRFXVARS`nvl'!="null"  {		// If prefixvar is non-empty this is a multivariate analysis
		 	local dvar = PRFXVARS`nvl'							// If there are prfxvars then we have a multivariate analysis
			local isprfx = "isprfx"								// So retrieve the depvar and set the the multivariate flag
		 }
		 if PRFXSTRS`nvl' !=""  local dprefix = PRFXSTRS`nvl'
		 local indepvars = VARLISTS`nvl'

		 if `c'==1 | "`extradiag'"!=""  {				 		// Display these diagnostcs while processng 1st contxt			**
			if `limitdiag' !=0 & `c'<=`limitdiag'   {																	
			   if "`isprfx'"==""  noisily display ///
			      "Generating {bf:`yiprefix'varname} from each of {bf:`indepvars'}; `nostacks' `nocontexts'"
			   else  {
				  noisily display _newline ///
				 "Regressing `dvar' on `indepvars', saving Y-hats in {result:`ydprefix'_`dvar'}; `nostacks' `nocontexts'"
			   }										 		// (in version 2 users see a 'y' on front of prefix)
			}											

		 } // endif `c'==1																										**
				
				
		 if "`wtexplst"!=""  {									// Now see if weight expression is not empty in this context

			local wtexpw = word("`wtexplst'",`nvl')				// Obtain local name from list to address Stata naming problem
			if "`wtexpw'"=="null"  local wtexpw = ""
				 
			if "`wtexpw'"!=""  {								// If 'wtexp' is not empty (don't non-existant weight)
				local wtexp = subinstr("`wtexpw'","$"," ",.)	// Replace all "$" with " "
			}
			
		 } //endif 'wtexplst'
		
		
		
		
global errloc "genyh(3)"
	

											// (3) Heavy lifting is done in program predcent (below)
											
set tracedepth 5
*		 ********
		 predcent `indepvars' `wtexp', depvarname(`dvar') cen(`cen') isprfx(`isprfx') logit(`logit') extradiag(`extradiag') ///																	
*		 ********												// Code for called program follows code for this one
set tracedepth 4
				


				
				
global errloc "genyh(4)"


											// (4) Post-process the results, if optioned
											
					
		 if ("`effects'"!="" & "`effects'"!="no") {				// I DON'T KNOW HOW TO TIDY THE OUTPUT									***

			local usefile = ""
			if ("`effects'"!="window") {
				local usefile = "using `yhat'.`effects'"
			}

			else {
				quietly display "{p_end}" _continue
			}

			if ("`logit'"=="logit") {							// Logit analysis
				local cellfmt = "z(fmt(3) star)"
				if ("`efmt'"!="") {
					local cellfmt = "`efmt'"
				}
				esttab `usefile', cells("`cellfmt'") pr2(%8.3f) mtitles replace compress wide onecell plain label
			}

			else {												// Regression analysis
				local cellfmt = "z(fmt(3) star)"
				if ("`efmt'"!="") {
					local cellfmt = "`efmt'"
				}

				if ("`efmt'"=="beta") {
					esttab `usefile', beta(%8.3f) not constant star ar2(%8.3f) mtitles replace compress wide onecell plain label
				}

				else {
					esttab `usefile', cells("`cellfmt'") ar2(%8.3f) constant mtitles replace compress wide onecell plain label
				}

			} //end else

		 } //endif `effects'
	
	


global errloc "genyh(5)"
	
											// (5) Break out of `nvl' loop if `postpipes' is empty
											// 	   (or pre-process syntax for next varlist)

		 if "`postpipes'"==""  continue, break					// Break out of `nvl' loop if `postpipes' is empty 
																// Else ...
		 local anything = strltrim(substr("`postpipes'",3,.))	// Strip leading "||" and any blanks from head of `postpipes'
																// (`anything' now contains next varlist and any later ones)
		 local isprfx = ""										// Switch off the prefix flag if it was on

				   
				   
	   } //next `nvl' 											// (next list of vars having same options)
				
	   if $exit==0 {
		  if (`nc' > 1 &`limitdiag'!=0  &`c'<`limitdiag') { 	// Display diagnostics, if optioned
			 noisily display _newline "Context {result:`c'} ({result:`contextlabel'}) has `numobs' cases"
		  }
	   }
			
*	} //endif $exit=0


	local skipcapuure = "skip										// If this command is executed then there were no errors above



} //end capture

If _rc & "`skipcapuure"!=""  {

	errexit "Stata has diagnosed a program error

} //endif _rc
			
	

end genyhatsP



******************************************************** END genyhatsP ********************************************************





***************************************************** SUBROUTINE predcent *****************************************************



capture program drop predcent  				
											

program define predcent   					// Program to predict and center variable(s) on their means/constants

	version 9.0

	syntax varlist [aw fw iw pw] , depvarname(varname) cen(string) [ logit(str) isprfx(str) extradiag(str) * ] ///
								   
								 
								 
								 
								 
	if "`cen'"=="null"  local cen = ""						// Argument cannot travel as an empty string; should be absent
	
	if "`weight'"!="" local wt = "[`weight'`exp']"
	if "`extradiag'"==""  local quietly = "quietly"

	local dvar = "`depvarname'"
*	local cen = "`center'"
	local nvars = wordcount("`varlist'")
	
	
	if "`isprfx'"!=""  {									// Multivariate analysis for which `varlist' provides indeps
		
		local yhat = /*"`ydprefix'"*/"d_`depvarname'"		// (yhats have `dprefix')		
		capture quietly generate `yhat' = .			

		if "`logit'"==""  {									// If `logit' was NOT optioned ...
*			qui capture reg `dvar' `varlist' `wt'			// DONT UNDERSTAND THE LOGIC HERE, SO COMMENTED OUT
			local rc = _rc									// Save RC for use below
			if "`extradiag'"!="" reg `dvar' `varlist' `wt' // If insufficient obs or other error, leave result missing
			else  qui capture reg `dvar' `varlist' `wt'		// Quietly unless extradiag was optioned
		}
		
		else  {												// `logit' was optioned
*			qui capture logit `dvar' `varlist' `wt' 		// COMMENTED OUT 'COS DONT FOLLOW THE LOGIC
			if "`extradiag'"!="" logit `dvar' `varlist' `wt' // Quietly unless extradiag was optioned
			else qui logit `dvar' `varlist' `wt'			
			if _rc>0 local rc = _rc							// If insufficient obs or other error, leave result missing
		}

		if `rc'==0  {										// If there are sufficient cases for this analysis
			tempvar NN			
			quietly predict `NN'							// Tempvar holds prediction that will replace `yhat'
			quietly replace `yhat' = `NN'

			if "`cen'"!=""  {								// If centering was optioned ...
				if "`cen'"=="con" {
					local adj =_b[_cons]					// Adjust by subtracting constant if optioned
				}											// (both _b and _cons are system _variables (see 'help _variables'))

				else  {										// Else subtract mean ...
					quietly sum `yhat' `wt', meanonly		// Need weighted mean of the `yhat'
					local adj = r(mean)
				}

				if "`logit'"==""  {
					quietly replace `yhat' = `yhat' - `adj' // This is a regression adjustment (straightforward)
				}											

				else  {					
					tempvar exponNN							// Else this is a logit adjustment ...
					qui gen `exponNN' = logit(`yhat')
					if "`cen'"=="con"  {
*						replace `yhat' = invlogit(expon`NN'-_b[_cons])
					}										// (Logit does not have a constant))

					else  {									// Need weighted mean of the logit(`yhat')
						quietly sum `exponNN' `wt', meanonly 
						quietly replace `yhat' = invlogit(`exponNN'-r(mean))
						capture drop `exponNN'
					}

				} //end else logit adjustment

			} //endif centering

			drop `NN'
				
		} //endif _rc

	} //endif multivariate


		
	else  {											 		// Multiple bivariate analyses: one analysis for each indep

		foreach indep of local varlist  {					// (yhats have `iprefix') 

			local yhat = /*"`yiprefix'*/ "i_`indep'"
			capture quietly generate `yhat' = .

			if "`logit'"==""  {								// If `logit' was NOT optioned ...
				capture reg `dvar' `indep' `wt'
				local rc = _rc								// If insufficient obs or other error, leave result missing
				if (`rc' == 0 & "`extradiag'"!="") reg `dvar' `indep' `wt'
			}

			else {											// `logit' was optioned
				capture logit `dvar' `indep' `wt'
				if (_rc == 0 & "`extradiag'"!="") logit `dvar' `indep' `wt'
				if _rc>0 local rc = _rc						// If insufficient obs or other error, leave result missing
			}
				
			if `rc'==0  {									// If sufficient cases for this analysis

				tempvar NN									// Tempvar holds predictions that will replace `yhat's
				quietly predict `NN'
				quietly replace `yhat' = `NN'

				if "`cen'"!=""  {							// If centering was optioned ...
					if "`cen'"=="con"  {
						local adj = _b[_cons]				// Adjust by subtracting constant if optioned
					}

					else  {									// Else subtract mean ...
*						quietly sum `yhat' `wt', meanonly	// Need weighted mean of the `yhat'
						qui mean `yhat' `wt'	
*						local adj = r(mean)
						matrix b = e(b)
						local adj = b[1,1]
					}

					if "`logit'"==""  {
						quietly replace `yhat'=`yhat'-`adj' // This is a regression adjustment (straightforward)
					}											

					else  {					
						tempvar exponNN						// Else this is a logit adjustment ...
						qui gen `exponNN' = logit(`yhat')
						if "`cen'"=="con"  {
							replace `yhat' = invlogit(expon`NN'-_b[_cons])
						}

						else  {								// Need weighted mean of the logit(`yhat')	??			***
*							quietly sum `exponNN' `wt', meanonly 
							qui mean `var' `weight'	
*							quietly replace `yhat' = invlogit(`exponNN'-r(mean))
							matrix b = e(b)
*							quietly replace `yhat' = invlogit(`exponNN'-r(mean))
							quietly replace `yhat' = invlogit(`exponNN'- b[1,1])
							capture drop `exponNN'
						}

					} //end else logit adjustment

				} //endif centering

				drop `NN'

			} //endif _rc

		} //next `indep'

	} //end else bivariate

	
	
end predcent



***************************************************** END SUBROUTING predcent **************************************************


