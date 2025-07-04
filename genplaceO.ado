
capture program drop genplaceO					// This program prepares the entire working dataset for calls on cmd'P

program define genplaceO, rclass				// This program is called before selecting working data for `genplaceP'


												
*! genplaceO (12/10/24) for Stata version 9.0 (8/25/23 by MNF) is a new program that contains opening code for
*! genplaceP, pre-processing the multi-varlists prepared by stackmeWrapper for passing on to genplaceP. In the 2024
*! version of stackMe 2.0, the two-part genplace (actually three-part since so much of the work of genplace was done in
*! stackmeWrapper) exemplifies an experimental structure that is already being progressively adopted by other stackMe
*! commands. In this structure `cmd'O is given what had been wrapper and those `cmd'P codeblocks that previously had been 
*! executed using data for the first context but some of which can now be executed using data for the full dataset, with 
*! some advantages mentioned below. Program control is returned to stackmeWrapper in time for that program to initiate the
*! final `cmd'P loop that processes each varlist in the multivarlist set of varlists for calls on (optional) user-supplied 
*! subprograms (and so, for the most part, will exit immediately). The new structure obviates a Version 2 problem that
*! had not previously been addressed: the problem that might arise for certain stackMe commands (ironically not for
*! genplace where the old structure was perfectly fine from this viewpoint) if different contexts have different numbers
*! of stacks or different minimum and maximum values for critical variables. The new structure allows the number of
*! stacks and the range of each variable to be standardized across contexts by being based on features of the dataset 
*! as a whole rather than on features of each context, as in the current versions of certain commands other than gen-
*! place. The new structure will also reduce by one (sometimes two) the chain of programs intervening between wrapper
*! and the generation of new data that were previously nested within the `cmd'P itself.
*!
*! In this version, genplaceO takes advantage of having access to the full dataset to access it at a lower level than
*! other stackMe programs, the context level rather than the stack level, so as to process the stacks themselves.



pause (1)
global errloc "genplaceO(1)"

										// SEE FIRST *** BELOW FOR NOTE ABOUT USING GLOBALS IN WRAPPER						***

										// (0) genplaceO for stackMe version 2 preliminaries
	version 9.0

*****************
capture noisily {											// Capture braces enclose code in which errors will be captured
*****************
	
	syntax anything [ aw fw iw pw ] , [ CWEight(varlist) INDicator(varlist) MPRefix(name) PPRefix(name) IPRefix(name)]  ///
				   [ CALl(string) LIMitdiag(integer -1) WTPrefixvars NOPLUgall TWOstep EXTradiag ctxvar(string) ]		///
				   [ NOContexts contextvars(varlist) nc(integer 1) nvarlst(integer 1) tempcntxt(string) wtexplst(string) *]
				   
															
			
*set trace on			
															
										// (1)  Prepare to cycle thru contexts (excluding stacks from those contexts); check
										//		cweight for reasonable distributional characteristics
	
	
	if `nc'>1 local multiCntxt = "multiCntxt"				// Flag widely used in 'stackmeWrapper', much of whose code is
															//  reused here
	local contexts :  char _dta[contextvars]
	if "`contextvars'"!="" {
		local contexts = "`contextvars'" 					// Get contextvars from a data characteristic unless overridden
	}														// by user option (this is how wrapper processing treats them)
	else if "`contexts'"=="nocontexts" local contexts = ""  // Make 'contexts' empty if characteristic recorded 'nocontexts'

	if "`mprefix'"!=""  {
		display as error "Option 'mprefix' not permitted for {cmdab:genpl:ace}; default 'pm_' is unchanged"
*						  12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		local mprefix = "pm_"								// (mprefix is used for 1st step and not an outcome)
	}														// Other prefix options will be honored in calling program
															// (after return from wrapper after calls on genplaceP)
	if "`contexts'"!=""  {
		capture label drop l1
		tempvar tempctx
set trace off
		quietly _mkcross `contexts', generate(`tempctx') missing strok labelname(l1) // Used in codeblk (4)
set trace on
		quietly sum `tempctx'
		local nc = r(max)									// This is the number of contexts (`c'), used below and in `cmd'P
	}
	else local nc = 1										// If no contextvars then # of contexts is just 1
	
	if `limitdiag'==-1  local limitdiag = .					// Unlimited diagnostics optioned; make that a big numbr
	
	if `limitdiag'  {	

	   local rmin = 0										// Initialize 'cweight' min as unproblematic
	   local outrnge = 0									// Same for mean

	   if "`cweight'"!="" {									// If cweight was optioned for 'genplace'
		
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
	  
	   } //endif 'cweight'								
	  
	} //endif 'limitdiag'	
	
	


global errloc "genplaceO(2)"

	
	
										// (2) deal with optns (these are the same for all varlists in set)
	
	
	if "`indicator'"!=""  {										// The variable that defines the placements, if optioned

		gettoken ifwrd rest : indicator							// See if "if" keyword is first word in 'indicator'
		local errstr = ""										// Set error string initially blank
				
		if "`ifwrd'"=="if"  {									// If "`indicator'" string starts with "if"
		    gettoken ifind rest : rest, parse(")")				// Rest of if-expresseion ends with close parenthesis
			if "`rest'"!="" {
				local ifind = "`rest'"							// Extract if-expressn & put in `ifind' ('ifexp' holds varlst if exp)
				tempvar indicator								// If indicator is created with 'ifind', make it a tempvar
				qui generate `indicator' = 0					// So generate a new var with 'indicator' name, 0 by default
				qui replace `indicator' = 1 `ifind'				// Replace values of that variable to accord with 'ifind' expression
		    }
		}														// ('ifind' may include varname(s) but don't need to keep those)
		else unab indicator : `indicator'						// Else 'indicator' contains a varlist; have unab check it
	
	} //endif													// Else, saving prefix indicators, must be placing varlist vars


	
	
pause (3)
global errloc "genplaceO(3)"	
	
										// (3) Cycle thru all varlists included in this call, reducing them to local strings and
										//	   making various checks for conformity with expectations
										
										
	local postpipes = "`anything'"								// Pretend we are picking up after the previous pipes
	if substr("`postpipes'",-2,2)=="||"  {						// If final 2 chars of 'postpipes' are "||"..
		local postpipes = substr("`postpipes'",1,strlen("`postpipes'")-3)
	}															// Strip off final pipes if present
	local lastvarlst = 0
										// THESE SHOULD HAVE BEEN SAVED IN stackmeWrapper GLOBALS								***
										
	local keep = ""												// Accumulate a list of vars created by genplaceO (NOT DONE)	***
	local errflg = 0											// Set to eliminate redundant error msgs
																  	
	forvalues nvl = 1/`nvarlst'  {								// Cycle thru each varlist in the multivarlst for `cmd'P
		
		local vars`nvl' = ""									// Create a local vor each varlist
		local pfxvars`nvl' = ""									// Create a local for each list of prefixvars
	    if "`wtexplst'"!=""  {									// THIS SHOULD BE MOVED TO CODEBLK 4							***
			local weight = word("`wtexplst'",`nvl') 			// Re-create the weight string passed from wrapper
			if "`weight'"=="null" local weight = ""				// (this weight expression will be used only for a 1st step)
			else local weight = subinstr("`weight'","$"," ",.)	// Replace any "&" with blank
		}
		else local weight = ""									// No weight yields empty 'weight' var (invisible to syntax cmd)
		
		gettoken prepipes postpipes: postpipes, parse("||")		//`postpipes' then starts with "||" or is empty at end of cmd
		if "`postpipes'"==""  local lastvarlst = 1				// MAY BE REDUNDANT												***
		 				
		gettoken precolon postcolon: prepipes, parse(":")		// See if varlist starts with indicator prefix 
		
		if "`wtprefixvars'"!=""  {								// If user optioned prefixvars to be weights
			if "`postcolon'"==""  errexit "Option 'wtprefixvars' suggests prefix vars but there are none"
			if "`cweight'"!=""  noisily display "cweight prefix vars would override cweight option `cweight'; continue?"
*							                12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure "cweight prefix vars would override cweight option `cweight'; continue?"
			if _rc errexit "Without permission to override cweight option"
			else noisily display "With prefix variables taking precedence, execution continues..."
			local cweight = substr("`postcolon'",2..)			// Store (list of) weightvars (pending check for preul @ 3.1)
		} //endif 'wtprefixvars'
		
		else {													// Else we could have indicator prefix-vars
		
		  if "`postcolon'"!="" {
			if "`indicator'"!=""  noisily display "Indicator prefix vars would override indicator option `indicator'; continue?"
			capture window stopbox rusure "indicator prefix vars would override indicator option `indicator'; continue?"
			if _rc errexit "Without permission to override indicator option"
			local indicator = substr("`postcolon'",2..)			// Store (list of) indicatorvars
		  }
		} //endelse												// In the absence of possible string prefix we would be done

		

		
pause (3.1)
global errloc "genplaceO(3.1)"



		local pfx = ""											// By default there is no string-prefix
		if "`postcolon'"!=""  {									// BUT, if there was a colon, head of precolon might be strprfx
		   gettoken preul postul : precolon, parse("_")			// DONT EXPECT PRE-UNDERLINE STRING, but code is just-in-case	***
		   if "`postul'" != ""  {								// If postul is not empty there IS an underline char..
		     if "`wtprefixvars'"!="" local cweight = substr("`postul'",2,.) // if optd, replace 'cweight' with ":"-trimmed postul 
			 else local indicator = substr("`postul'",2,.) 		// Else not opted so replace 'indicator' with ":"-trimmed postul
		     local pfx = "`preul'_"								// And store pre-"_" string in 'pfx' (with "_" suffix)
		   } //endif 'postul'!=""
		} //endif 'postcolon'!=""								// Else prepipes has no colon, only varname(s)
	 
		else  local vars`nvl' = "`prepipes'"					// No colon so prepipes has indepvars, ending with pipes or not
	  
		local len = strpos("`vars`nvl''","||") - 3				// Get length of varlist up to char before next "||", if any
	  
		if `len'>0 local vars`nvl'=substr("`vars`nvl'",1,`len') // If there were any pipes strip them from end of 'vars`nvl''
		
		
		
		
		local errflg =0											// No error has yet been reported
	  
		foreach v of local vars`nvl'  {							// cycle through vars in this varlist
		
		   local indlst = ""									// List of (optnly-prfxd&suffxd) indicator vars (initially empty)
		   local cwtlst = ""									// List of (optionaly-prfxd&suffxd) weight vars (initially empty)
		
		   local nwt = wordcount("`cweight'")  					// Number of cweight vars (no more than 1 if multiple indicators)
		   local nin = wordcount("`indicator'")					// Number of indicator vars (no more than 1 if multple cweights)
		   
		   local wv = pp_`v'									// Default outcome varname (working variable)
		   if "`twostep'"!=""  local wv = "pm_`v'"				// Default name changed to 'pm_`v'' if twostep process
		   
		   
		   local j = 1
		   local k = 1
		   
		   while j<=`nwt'  {									// First loop is entered even if no cweight (minimum is =1)
		   
		     while `k'<=`nin'  {								// Ditto for no indicators
			 
			  if `nwt'>=1  {									// 'cwtlst' remains empty if `nwt' is 0
			    foreach cwt of local cweight  {					// 'cweight' is either empty or has name(s) of cweight vars
				  local cwtlst = "`cwtlst' `pfx'`cwt'_`v'"		// These would weight mean values placed in pm_*, pp_*, or ind_*
				}												// (would be only 1 var if 'indicator' had multiple vas)
			  }

			  if `nin'>=1  {									// 'indlst' remains empty if 'nin' is 0
				foreach ind of local indicator  {				// These will override any 'wv' working variable(s)
				  local indlst = "`indlst' `pfx'`ind'_`v'"
				} //next 'ind'									// (would be only 1 var if 'cweight' had multiple vars)
			  } //endif

/*																// COMMENTED OUT 'COS SEEMINGLY UNNECESSARY						***
			  if "`indicator'"=="" 	{							// If no indicator use pi_ or cweight as prefix
				 if `ppv' & !`nwt'  {							// If pp_-prefxd input name and no cweight
					local errlst = "`errlst' `wv'"				// Add the offending varname to 'errlst'
				 }												// ('ppv' and 'errlst' were established before 'while', above)
				 else  {
				 	if `nwt'==0  {
					   local keep = "`keep' pp_`v'"				// Accumulate additional vars to be kept in working data
					}
					else  {
					   local keep = "`keep' `cwt'_`v'"			// Accumulate additional vars to be kept in working data
					}
				 } //endelse									// (pp_`v' is not assigned `tmp' if error would result)
			  } //endif											// (instead, 'errlst' got the offending varname)
				 
			  else {											// Else there is an indicator
				 if `nwt'==0  {
				    local keep = "`keep' `ind'`v'"				// Accumulate additional vars to be kept in working data
				 }
				 else  {
				    local keep = "`keep' `ind'`cwt'_`v'"		// Accumulate additional vars to be kept in working data
				 }
			  } //endelse
*/			  
			  local nin = `k' + 1								// Ditto for indicators
		 
			} //next 'nin'	

		    local nwt = `j' + 1	
		  
		  } //next `nwt'
		  
		  capture drop `tmp'
		  capture drop `wv'										// Drop the working variables before moving to next 'v'
		  
		  
		  if !`errflg' { 
		  	
		    local label : variable label `v'					// Get this var's varlabel
		
		    if substr("`label'",1,4)!="stkd" & !`errflg'  {		// If no 'stkd' in var label, this var was not stkd by genst
			  display as error "Variable `v' has no 'stkd' flag in its var lable; overlook such errors?"
*							    12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  capture window stopbox rusure ///
								"Variable `v' has no 'stkd' flag in its var label; continue anyway, overlooking such errors?"
			  if _rc  {
				  errexit "Without permission to drop apparently unstacked variables,"
			  }
			  local errflg = 1									// Prevents additional error msgs for other vars
			  
			} //endif label
			
		  } //endif 'errflag'
			
	    } //next `v'											// Next variable if any		  
		  
	} //next 'nvl'(nvarlist)

	

	
pause (3.2)
global errloc "genplaceO(3)"	


	
	if "`twostep'"!=""   {										// Two-step HAS been optioned
		
		if "`noplugall'"!=""  {
			display as error "Cannot have option 'plugall' without option 'twostep'"
			errexit "Cannot plugall without twostep, so"
		}
	  															// (in 'cmd'O we don't treat stacks as contexts, unlike cmd'P)
		if `limitdiag'  {
			if "`indicator'"=="" noi display "Generating 1st-step 'pm_'-prefxd placements of batteries distinguishd by SMstkid"
*					  				      12345678901234567890123456789012345678901234567890123456789012345678901234567890 
		}
			
	} //endif 'twostep'
	
	  
	if "`indicator'"!="" | ("`pfxvars`nvl'"!="" & "`wtprefixvars'"=="") { 
		if `limitdiag' noi display "Generating indicator-prefixed placements of indicator variable(s) across SMstkid"
	}															// (and pi-prefixed batteries, if optioned)
	   
	if "`cweight'"!="" | ("`pfxvars`1''"!="" & "`wtprefixvars'"!="")  {	
		if `limitdiag'  noisily display "weighting the mean placements by each of cweight vars `cweight'"
	} //endif 'cweight'											// If conditions are met for weighted placements
		  
	
	tempfile placedta											// File in which to save workng dta in memory to be merged with
	tempvar origunit											//   new vars before exiting 'genplaceO'
	gen `origunit' = _n											// Var that will be in both files, for merging
																// (a different tempvar than `origunit' in 'origdta')
																
*	***********************	
	quietly save `placedta'										// Will hold data to be merged back into working dataset
*	***********************										// (in codeblk (8) below)
	

	
pause (4)
global errloc "genplaceO(4)"	

											// (4) Cycle thru all contexts (not including stacks as contexts)
											
				
	local lbl = "this dataset"									// Label updated right below if there is >1 context
	
	local allnotconst = ""										// Initialize list of means not constant across units
	
	local notconst = ""											// List will hold names of vars lacking constant values 
	local fix = 0												// Flag determines whether user has 'ok'd fix for this
	local reported = 0											// Flag to indicate whether errors have been reported
	local addconst = ""											// List of additional constant vars after 1st contxt

	
	
	

*	********************										// (in any varlist or context)
	forvalues c = 1/`nc'  {
*	********************
		
	  if `nc'>1  {												// If there is more than one context..
	  	 local lbl : label l1 `c'
		 local lbl = "context `lbl'"							// We need to label those contexts
	  } 	
			
*	  ******************************
	  preserve
			
	  quietly keep  if `c'==`tempctx'
*	  ******************************
																// NOTE THAT NOW WE ARE ONLY PROCESSING ONE CONTEXT
	  
	  quietly levelsof SMstkid, local(stks)						// This will be the same for all vars in this context
	  local firststack = word("`stks'",1)						// Put SMstkid # of lowest SMstkid into 'firststack'
	  if SMstkid[1] != `firststack'  sort SMstkid				// Need lowest SMstkid first in dataset to ensure not missing
		
	  forvalues nvl = 1/`nvarlst'  {							// Cycle thru each varlist in the multivarlst for `cmd'P
																// For just this varlist:
	  	
	    if "`wtexplst'"!="" local weight = word("`wtexplst'",`nvl') // Re-create the weight string passed from wrapper
	    if "`weight'"=="null" local weight = ""					  // (this weight expression is used only for 1st step)
	    if "`weight'"!="" local "`wtexp'" = subinstr("`weight'","$"," ",.) // Replace any "$" by spaces
	
	    local varlist = "`vars`nvl''"
		local pfxlist = "`pfxvars`nvl''"							
		
		if "`pfxlist'"!=""  {									// If a prefix-list of varname(s) preceeded the varlist
		  if "`wtprefixvars'"!="" local cweight = "`pfxlist'"	// Over-write any optioned 'cweight' if `wtprefixvars' was optd
		  else  local indicator = "`pfxlist'"					// else overwrite any optioned 'indicator'
		}

		
		
		
*	    if !`reported'  {										// DISCOVERING non-constant values MAY only need to happen once?***

		  foreach v of local varlist  {							// Supposedly fastest 'foreach' (only 'forvalues' is faster)	***
		
			tempvar rsd
set trace off
			egen `rsd' = sd(`v'), by(SMstkid)					// Get stdev for this var in this context
set trace on
			if `rsd'[1]!=0  {									// If sd is not 0 ..
			   if strpos("`notconst'","`v'")==0   {				// If this var is not already in 'notconst' from prev varlist?..
				  if `reported' local addconst="`addconst' `v'" // Can report these separately after final context
				  local notconst = "`notconst' `v'"				// Then add to list of non-constant means in this varlist
			   }												// (assumes lowst SMstkid is !missing (assured by sort, above)
			} //endif rsd[1]
			drop `rsd'											// Drop tempvar before continuing to next variable
			
		  } //next 'v'
		  
		  
		
		  if "`notconst'"!="" & !`reported'  {					// If non-constant mean(s) have been found
			
		    if !`reported' display as error "Stack mean(s) not constant across units in `lbl' for vars:"
*						    12345678901234567890123456789012345678901234567890123456789012345678901234567890

		    if "`twostep'"=="" & `fix'==0  {					// Only report error the first time
		  	
		       display as error ///
						   "`notconst';  continue anyway?{txt}" // Vars are listed before question posed
			   local msg = "Not a 2-step placement, so stack means should normally be constant over units"
*						 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			   display as error "`msg'" _newline "Fix this so stack means are constant across units?"
		       capture window stopbox rusure 				   ///
		        "`msg' but not in context `lbl' and perhaps elsewhere. Fix this so means are constant across units?"
		       if _rc==0  {
				 local fix = 1
				 if `limitdiag' noisily display "Execution continues with stack means constant across units..."
*												12345678901234567890123456789012345678901234567890123456789012345678901234567890
			   } //endif _rc==0
			   else  if `limitdiag' noisily display "Execution continues with stack means that vary across units..."
			
		    } //endif 'twostep'



			
pause (4.1)			
global errloc "genplaceO(4.1)"



		  
		    else  {												 // Else twostep was optioned

			  display as error "You optiond a two-step genplace but named mean(s) are not constant across units:"
*						        12345678901234567890123456789012345678901234567890123456789012345678901234567890
		      display as error "`notconst'; is this what you want?{txt}" 
																// Vars are listed before question posed
			  noisily display "With a two-step placement you might want response values, not means; continue?"
*						       12345678901234567890123456789012345678901234567890123456789012345678901234567890
		      capture window stopbox rusure					   ///
				  "With a two-step placement you might want response values, not means; if so, continue as is?"
		      if _rc  {											// If user did not 'ok' continuing as is
			      noisily display "Fix data so stack means are constant across units?"
			      capture window stopbox rusure "Fix data so stack means are constant across units?"
			      if _rc == 0   {
			   	    local fix = 1						  		// Fix if user clicked on 'OK'
			      }
				  else  errexit "Neither continue nor fix implies termination"
			  } //endif _rc
			  
			  else if `limitdiag' noisily display "With stack means varying across units, execution continues..."
			
		    } //endelse
		  
		    local reported = 1
		  
		  } //endif `notconst'
		
*		} //endif !`reported'									 //	This block CLD BE exctd ONLY until non-constant values found***		
																 // (MAYBE COULD REDUCE TO 1ST STACK OF EACH CONTEXT?)			***
						
		
		if `fix'  {												// If fix was optioned (execute for all contexts)
		  
		   foreach v of local notconst  {						// Cycle thru non-constant vars
		  	  tempvar tmp
		      egen `tmp' = mean(`v'), by(SMstkid)  				// 'tmp' could be either pm_-prefxd or unprefixed
			  replace `v' = `tmp'								// Replace that variable with its context means
			  drop `tmp'										// (different constant mean for each stack)
		   } //next `v'
		   
		   if `limitdiag'  noisily display "With stack means constrained to invariance across units, execution continues..."
*						                    12345678901234567890123456789012345678901234567890123456789012345678901234567890
*		    local fix = 0										// COMMENTED OUT 'COS NEEDS TO BE DONE FOR ALL CONTEXTS			***
		   
	    } //endif 'fix'
	


pause (5)
global errloc "genplaceO(5)"
	  
											// (5)  Cycle thru all varlists included in this call; (each input variable is some
											//		variant of `v' (`v' or 'mv' input for pp_`v' or pi_`v' outcome).
											

	    foreach v of local varlist  {							// Supposedly fastest 'foreach' (only 'forvalues' is faster)	***

																//							  ******************************
		   if "`twostep'"!=""  {								// Twostep has been optioned, THIS IS WHERE 1ST STEP IS DONE
																//							  ******************************

			  tempvar tmp`v'									// Will be renamed to pm_`v' when holds outcome values
		  
		      if "`weight'"!=""  {								// If unit-level weighting was optioned
		    
			    mean `v' `weight', over(SMstkid)				// Get mean stack value by using cmd 'mean'
			    matrix means = e(b)								// Get matrix of mean values returned by cmd mean
			    local i = 0
			    foreach stk of local stks   {					// Cycle thru the all stacks (from levelsof, codeblk 4)
			      local i = `i' + 1								
			      gen `tmp`v''= means[1,'i'] if SMstkid==`stk'	// Retrieve mean `v' for each stack; put in tmp`v'
			    } //next 'stk'
		  	
			
		      } //endif 'weight'
		  
		      else  {											// Else data are not weighted (this code should run faster)
																
			    egen `tmp`v'' = mean(`v'), by(SMstkid)			// Generate mean`v' separately for each stack
																// (should be faster than cmd 'mean)
		      } //endelse 'weight'
		  
		      if "`noplugall'"!=""  {							// If 'noplugall' is opted we replace invariant means
		  	     quietly replace `tmp`v''= `v' if !missing(`v')	// (with no-missing values of input `v')
		      }
		  
		      rename `tmp`v'' pm_`v'							// Either way, rename the tempvar to desired outcome name
																// (desired because it uses the first step outcome prefix)
		  } //endif 'twostep'									// Either way, continue with 2nd step in 'genplaceP2'
	
																// Now continue with code for both twostep and not
																
	  
pause (6)	  
global errloc "genplaceO(6)"				// WHY DO WE GET VALUES ASSIGNED TO NEW VARIABLES ONLY FOR THE FIRST CONTEXT??		***
	  
											// (6)	Generate 'pp_'- or 'pi_'-prefixed outcome vars, whether from `v' or 'pm_`v'
											//		or 'pp_`v' inputs ('wv' is either `v' or `'pm_'; but `v' might be 'pp_'v'
											//		if the varname of the varlist variable has that prefix
											
		   
		  local nwt = wordcount("`cweight'")  					// Number of cweight vars
		  local nin = wordcount("`indicator'")					// Number of indicator vars
		  tempvar tmp											// Tempvar will hold mean for each stack
		   
		  local wv = `v'										// Default input varname (working variable)
		  if substr("`wv'",1,3)=="`pp_'"  local ppv = 1			// If listed varname has pp_ prefix, flag this with `ppv'
		  else local ppv = 0									// (or not)
		   
		  if "`twostep'"!=""  local wv = "pm_`v'"				// Default name changed to 'pm_`v'' if twostep process
		  local errflg = 0										// Error flag halts duplicate error messages (UNUSED FOR NOW)	***
		  local errlst = ""										// List of pp_-prfxed varnames that duplicate input varnames
	  	
		  while (`nwt'+1)>0  {									// First loop is entered even if no cweight (minimum is =1)
		   
		    while (`nin'+1)>0  {								// Ditto for no indicators
			 
			  if "`cweight'"==""  local cwt = 1					// 'cwt' gets either the # 1 or name of a cweight var
			  else  local cwt = word("`cweight'",`nwt')			
			  if "`indicator'"=="" local ind = ""				// 'ind' is either empty of has name of an indicator var
			  else  local ind = word("`indicator'",`nin')+"_"	// (append "_" so becomes part of the indicator name)
			  
			  egen `tmp' = mean(`wv'*`cwt'), by(SMstkid)    	// 'tmp' is pm_* or `v*' (different constnt for each stack)
																// (`wv' is working variable, either pp_* or pm_* or pi_*)
																// (`tmp' is either weighted or not, depending on 'cwt')
			  if "`indicator'"=="" 	{							// If no indicator use pi_ or cweight as prefix
				 if `ppv' & !`nwt'  {							// If input name wld be same as outcome name & wtprfx not used
					local errlst = "`errlst' `wv'"				// Add the offending varname to 'errlst'
				 }												// ('ppv' and 'errlst' were established before 'while', above)
				 else  {
				 	if `nwt'==0  {
					   gen pp_`v' = `tmp'						// If no cweights & no indicator put placement in workng pp_
					}
					else  {
					   gen `cwt'_`v' = `tmp'*`cwt'				// Else put it in `cwt'-prefixed `v'
					}
				 } //endelse									// (pp_`v' is not assigned `tmp' if error would result)
			  } //endif	'indicator'								// (instead, 'errlst' got the offending varname)
				 
			  else {											// Else there is an indicator
				 if `nwt'==0  {
				    gen `ind'`v' = `tmp'*`ind'					// If no weight assign `ind'`v' ('ind' has integral "_")
				 }
				 else  {
				 	gen `ind'`cwt'_`v' = `tmp'*`ind'*`cwt'		// Else assign both prefixes  ('ind' has integral "_")
				 }
			  } //endelse
			  
			  local nin = `nin' - 1								// indicators are used from last to first, but namd corrctly
		 
			} //next 'nin'										// Indicators are used from last to 1st, but names are ok

		    local nwt = `nwt' - 1								// cweights are used from last to first, but namd corrctly
		  
		  } //next `nwt'
		  
		  
		  capture drop `tmp'
		  capture drop `wv'										// Drop the working variables before moving to next 'v'
			
	    } //next `v'											// Next variable if any
		
		if "`errlst'"!=""  {									// If there were name conflicts (pp_outcome matched pp_input)
		   display as error "Varlist would generate the following 'pp_'- prefixed vars that already exist:"
*					 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   noisily display "`errlst'"
		   errexit "Varlist would generate the following 'pp_'- prefixed vars that already exist: `errlst'; "
		}
			
/*		if "`notconst'"!="" & strpos("`notconst'","`v'")==0  local allnotconst = "`allnotconst' `notconst'"
		local notconst = ""
		local fix = 0											// ERRORS FROM ALL VARLISTS WERE ACCUMULATED IN 'notconst'
*/	
	  } //next 'nvl' 											// Next varlist if any
	  
	  
	  
	  
pause (7)
global errloc "genplaceO(7)"	  
	  
	  				
								// (7)	Here we append each context in turn to a tempfile for merging once all contexts have been 
								//		processed. This means that we start with a file for the first context to which we append 
								//		each subsequent context. After appending the final context we merge the whole file with 
								//		the 'placedta' file that provided input variables for 'genplace'.
								//  	THIS IS SAME CODEBLOK AS CODEBLOCK 8 IN stackmeWrapper, THO' TEMPFILES ARE NAMED DIFFRNTLY.
			
			

	   if `c'==1  {													// Here create tempfile for 1st context, named 'saveplace'
*		  ************************
		  tempfile wrapc1											// Declare tempfile to hold first context 
		  save `wrapc1'												// This file holds 1st contxt, basis for appending later cntxts
		  global wrapbld = c(filename)								// Path+name of latest datafile used or saved by any Stata cmd
*		  ************************
	   } 															// For subsequent sets of working data, each got by extracting
	   
	   else  {														// Else `c' enumerates a later context
	   
*	   	  *******************
		  tempfile wrapnxt											// Declare tempfile for current context (c2...cmax)
		  save `wrapnxt'											// Save this context in that file
		  global wrapnxt = c(filename)								// Path+name of latest datafile used or saved by any Stata cmd
		  *******************
		  
		  use $wrapbld
																	// This schlocks currnt context, ok 'cos next we restoe full dta
		  quietly append using $wrapnxt, nonotes nolabel			// SEEMINGLY NEED TO USE fullname PRAPS 'COS ARE IN DIFFRNT CNTXT
		  save $wrapbld, replace									// Replace $wrapbld with additional context appended
		  erase $wrapnxt
				
	   } //endelse


*	   *******
	   restore														// Here finish with temp data, briefly restore working dataset
*	   *******														// (briefly unless this is the final context or error exit)
				   

*	  **********		  
	} //next `c'													// Next context if any
*	  **********	

	if "`addconst'"!="" {
		display as error "Additional constant variables were treated as those first reported: " _continue
*					      12345678901234567890123456789012345678901234567890123456789012345678901234567890
		if strlen("`addconst'"<12  display as error "`addconst'"
		else display as error _newline "`addconst'"
	} //endif
	

*	****************
*	save `saveplace', replace										// No need to replace saveplace; it already has all contexts
*	****************												// Save tempfile for merging, in next codeblck, with 'origdta'
	  
	
	
	

pause (8)
global errloc "genplaceO(8)"	

	
	
									// (8)  Temporarily rename new variables whose names conflict with vars genrated previously; 
									//		then merge new vars, created above, with original data

	if "$prefixedvars"!=""	{										// If there are any candidates for name conflicts when merging 
																	// (candidates are listed in $prefixedvars)
	  foreach var of global prefixedvars  {							// This global was filled as a bi-product of wrappr codeblk (5) 
																	// (it holds a list of all prefixed vars to be generated by 'cmd)
		local prfx = strupper(substr("`var'",1,2))					// Change prefix string to upper case (it is followd by "_")
	    local tempvar = "`prfx'" + substr("`var'",3,.)				// All prefixes are 2 chars long and were previously lower case
		capture confirm variable `tempvar' 							// If it already exists we had the same conflict earlier
		if _rc==0  drop `tempvar'									// (the prefix is capitalized so the varname becomes distict)
		rename `var' `tempvar'										// Each 'var' has a "_" in 3rd character position
																	// (lower case prfixs will be restored in caller prog 'genplace')
	  } //next 'prefixedvars'										// (same final codeblk as handles uppr-case prfxs for each 'cmd')

	} //endif $prefixedvars


	
	
*	****************************										
	quietly use `placedta', clear									// Retrieve working data to merge with new vars in $saveplace 
*	****************************									// (vars extracted by 'stackmeWrapper' from vars in 'origdta')

	  
*	*****************	  
	quietly merge 1:m `origunit' using `wrapbld', nogen update replace
*	*****************												// Here the full temp file is merged back into `origdta'

*																	***********************************************************
																	// Results of merge are left in memory on return to wrapper
*																	***********************************************************
	erase `wrapbld' 
	erase `placedta'	
	
	
	
	local keepvars : list uniq keep
	
	
	return local keepvars `keepvars'								// Return a list of the variables generated above
	
																	// NEED TO COVER POSSIBILITY THAT DATA ARE DOUBLY-STACKED		***

	local skipcapture = "skip"										// No errors if exit above codeblocks at this point 

****************
} // end capture													// End of codeblocks where errors will be captured
****************

if _rc & "`skipcapture'"==""  {
												// Error handling for errors in above codeblocks comes here
	if _rc  errexit  "Stata flagged likely program error"

} //endif _rc &'skipcapture


end genplaceO														
			
			


			
													
