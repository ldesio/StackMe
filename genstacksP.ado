
capture program drop genstacksP

*!  This program makes calls on stackmeWrapper's varsImpliedByStubs subroutine (what Stata calls a 'program')

program define genstacksP

*!	Version 2 uses the command window to build label for stacked data; unlike version 2a which uses a dialog box.

*!  Stata version 16.1 (originally 9.0); genstacks version 2.0, updated Jan'23 & May'24 from major re-write in June'22.
*!  Search sreshape for a faster reshape command published in 2019 (possibly already incorporated into Stata 17)
*!  However, reshape is not the slow part. A faster merge command would be good!


	version 16.1				// stackMe's genstacks version 2.0, June 2022, updated 2'23, Aug'24, Nov'24
	
	// This version of genstacks reshapes each context separately. It does labeling of vars and data in `cmd' caller. It  
	// doesn't use Stata's code for duplicating variables that are not reshaped. Instead it saves those variables and later   
	// merges them with the reshaped variables. It uses external files for this rather than data frames, because of limitations   
	// on types of merges that frames support.
	//   An important component of the stacking operation happens in `stackmeWrapper', where stubnames are identified and 
	// checked. `genstacksP' (this ado file) reshapes and post-processes the stacked data to remove empty stacks and correct 
	// for fixed effects, if optioned.
	//   `genstacksP' calls a subroutine already called from stackmeWrapper to derive variable names implied by stubs used in
	// conformity with genstacks syntax 2 (see help file for genstacks).
	//   Trial versions used Stata's version # to evaluate use of frame technology where present. It used a call on Mata to 
	// get the version # (I was unable to discover how to get the version number from Stata itself.) thus: 
	// 'mata: st_numscalar("temp", statasetversion()', returns versn # in scalar 'temp'. Frames proved slower than tempfiles.

*set trace on

  syntax anything [aw fw pw/], [ CONtextvars(varlist) UNItname(name) STAckid(name) ITEmname(varlist) TOTstackname(name)] ///
							   [ REPlace NODiag KEEpmisstacks FE(namelist) FEPrefix(string) LIMitdiag(integer -1) NOCheck ]  ///
							   [ ctxvar(varname) nc(integer 0) c(integer 0) nvarlst(integer 1) wtexplst(string) ] 

							   
							   
							   
							   
							   
							   
							   // (1) Following codeblock executed for each context established in wrapper & recorded in `c'
					

  local w = 1												// By default warnings are displayed
  
  if `limitdiag'>0 & `c'>`limitdiag' local w = 0			// If limit not -1 & context>limit turn warnings off
															// (`w' flags diagnostics for this context, `nodiag' for any context)
															// (NOTE that nodiag is backwards; 0=none, !0=some)
  
  if `w'  local displ = "noisily"							// Prefix for 'reshape' command
  if !`w' local displ = "quietly"
															
  set more off
  
  local namelist = "`anything'"								// Get stubnames from argument passed by wrapper program	
															// (Wrapper did check that all stubs have corresponding varlists)
										
										
										
										
										
										
														
								// (2) For first context only: diagnose any errors in fe syntax
								
															// (fe options have been removed from help file but are still coded)
																
  if `c'==1  {												// If this is first context ...
  	
	 if ("`fe'"!="") {										// Prepare for fixed effects if optioned . . .

		local list = ""							
		foreach fevar of local fe  {
			if strpos("`namelist'","`fevar'") == 0  {		// If fevar is not in stub-list, add to list of inappropriate fe's
				local list = "`list' `fevar'"
			}
		} //next 'fevar'

		if "`list'"!=""  {
			display as error	"Not in varlist: optioned fe var(s) `list'"
	`		window stopbox note "Optioned fe variables not among vars to be processed (see list)"
			global exit = 1
			exit
		}
	
		if "`feprefix'"==""  {
			display as error "NOTE: No feprefix provided for optioned fixed effects; using 'fe_' as prefix"
		}															// Substituted in each context separately
						   // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		if `w' {
			noisily display "Applying fixed-effects treatment to fe-vars (subtracting unit-level means)"
		} //endif `w'												// Subtracted for each context separately
		
	 } //endif `fe'!=""
	 
	 
  } //endif `c'==1
	 
	 

	

								// (3) For each context: reshape, process fixed effects, drop empty stacks if optioned

				
  if `w' noisily display _newline "{bf:Context `c':}{txt}"			//`w' false after limitdiag reached
	
  if ("`fe'"=="_all")  local fe = "`namelist'"

  if "$dblystkd"==""  {												// If double-stacking is not wanted ...
		  
		
*		  ************************
		  tempvar SMstk												// If NOT to be doubly-stacked (just conventional reshaping)
	     `displ' reshape long `namelist', i(SMunit) j(`SMstk') 		// SMunit & S2unit were created in stackmeWrapper 
		  quietly replace SMstkid = `SMstk'							// Replace missing obs for var ordered after SMunit
		  drop `SMstk'
  }																	// `SMstk' & `S2stk' get succesive values from 'reshape')
  else  {															
		  tempvar S2stk												// If IS to be doubly-stacked (e.g. issues within parties)
		  `displ' reshape long `namelist', i(S2unit) j(`S2stk')		//`displ' is "quietly" if `w' ==0
		  quietly replace S2stkid = `S2stk'							// Replace missing obs for var ordered after S2unit
		  drop `S2stk'												// All this futzing attempts to avoid inexplicable problem
*		  ************************ 									//  with Stata's 'order..., after...' command
  }

 if "`keepmisstacks'" == "" | "`fe'" != ""  {						// If `keepmisstacks' NOT optioned or fixed effects IS optioned ...
	
	 if ("`fe'"!="")  {												// If fixed effects were optioned
		if ("`fe'"=="_all")  local fe = `namelist'
		foreach fevar of local fe  {
			capture qui sum `fevar' [aw fw pw/]						// Put weighted mean of each fevar new local for each context
			capture local mfevar = r(mean)							// Save in specific local for each fevar
			`displ' gen `feprefix'`fevar' = `fevar' - `mfevar' 
		}
	 }
		  	 
	 noisily display "." _continue

	 if "`keepmisstacks'"==""  {									// If dropping empty stacks (default) ...
		 tempvar stkmiss											// Flag to indicate stack all missing for this context
		 qui egen `stkmiss' = rowtotal(`namelist'), miss			// Set missing if rowtotal missing in this (perhaps only) context
		 qui drop if `stkmiss'==.									// Drop stacked observations that are all-missing in this context
		 drop `stkmiss'
	 }
	   
  } //endif keep misstacks | fe
		
	
																	// Much post-processing of stacked data is in genstacks calle
																
end //genstacksP




********************************************************** END OF PROGRAM *********************************************************

