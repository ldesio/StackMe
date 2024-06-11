
capture program drop genstacksP

*!  This program makes calls on stackmeWrapper's varsImpliedByStubs subroutine (what Stata calls a 'program')

program define genstacksP

*!	Version 2 uses the command window to build label for stacked data; unlike version 2a which uses a dialog box.

*!  Stata version 16.1 (originally 9.0); genstacks version 2.0, updated Jan'23 & May'24 from major re-write in June'22.
*!  Search sreshape for a faster reshape command published in 2019 (possibly already incorporated into Stata 17)
*!  However, reshape is not the slow part. A faster merge command would be good!


	version 16.1											 // stackMe's genstacks version 2.0, June 2022, updated 1'23, 2'23
	
	// This version of genstacks again reshapes each context separately. It does labeling of vars and data in `cmd' caller. It  
	// doesn't use Stata's code for duplicating variables that are not reshaped. Instead it saves those variables and later   
	// merges them with the reshaped variables. It uses external files for this rather than data frames, because of limitations   
	// on types of merges that frames support.
	//   An important component of the stacking operation happens in `stackmeWrapper', where stubnames are identified and 
	// checked. `genstacksP' (this ado file) reshapes and post-processes the stacked data to remove empty stacks and correct 
	// for fixed effects, if optioned.
	//   `genstacksP' calls a subroutine already employed in stackmeWrapper to derive variable names implied by stubs used in
	// conformity with genstacks syntax 2 (see help file for genstacks).
	//   Trial versions used Stata's version # to evaluate use of frame technology where present. It used a call on Mata to 
	// get the version #, thus: 'mata: st_numscalar("temp", statasetversion()', returns versn # in scalar 'temp'. Using frames 
	// proved slower than using tempfiles. (I was unable to discover how to get the version number from Stata itself.)



  syntax anything [aw fw pw/], [ CONtextvars(varlist) UNItname(name) STAckid(name) ITEmname(varlist) TOTstackname(name)] ///
							   [ REPlace NODiag KEEpmisstacks FE(namelist) FEPrefix(string) LIMitdiag(string) NOCheck ]  ///
							   [ ctxvar(varname) nc(integer 0) c(integer 0) nvarlst(integer 1) ] 

							   
							   
							   // (1) Following codeblock executed for each context established in wrapper & recorded in `c'
					
					
					

  local w = 1												// By default warnings are displayed
  
  if `limitdiag'>0 & `c'>`limitdiag' local w = 0			// If limit not -1 & context>limit turn warnings off
															// (`w' flags diagnostics for this context, `nodiag' for any context)
															// (NOTE that nodiag is backwards; 0=none, !0=some)
  
  if `w'  local displ = "noisily"							// Prefix for 'reshape' command
  if !`w' local displ = "quietly"
															
  set more off
  
  local namelist = "`anything'"								// Get stubnames from argument passed by wrapper program	
  
										
										
								// (2) Processed only for first codeblock: diagnose any errors in fe syntax
								
								
  if `c'==1  {												// If this is first context ...
  	
	 if ("`fe'"!="") {										// Prepare for fixed effects if optioned . . .

		local list = ""							
		foreach fevar of local fe  {
			capture confirm variable `fevar'
			if _rc  {
				local list = "`list' `fevar'"
			}
		} //next 'fevar'

		if "`list'"!=""  {
			display as error	"Not in varlist: optioned fe var(s) `list'"
	`		window stopbox stop "Optioned fe variables not among vars to be processed (see list)"
		}
	
		if "`feprefix'"==""  {
			display as error "NOTE: No feprefix provided so using 'fe_' as prefix"
		}

		if `w' {		  // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
			display "Applying fixed-effects treatment to fe-vars (subtracting unit-level means)"
		} //endif `w'

		if ("`fe'"=="_all")  local fe = "`namelist'"
		
		foreach fevar of local fe {
			if `w' noi display "`feprefix'`fevar' " _continue
			capture drop `feprefix'`fevar'
*			quietly bysort SMUnit': egen `t' = mean(`fevar')		// Prefer weighted calculation now done above								***
			`displ' gen `feprefix'`fevar' = `fevar' - `mfevar'		// `mfevar' generated for all contexts before if `c'==1
		}
		
	 } //endif `fe'!=""
	 
	 
  } //endif `c'==1
	 
	 
  
  	

	

								// (3) For all codeblocks, reshape, process fixed effects, drop empty stacks if optioned

				
  if "$dblystkd"==""  {												 // If not to be doubly-stacked
		if `w' noisily display "{bf:Context `c':}{txt}"
		
*		   	   ************************
	   `displ' reshape long `namelist', i(SMunit) j(SMstkid) // SMunit & S2stkid were created in wrapper 
  }
  else `displ' reshape long `namelist', i(S2unit) j(S2stkid) // Both get their succesive values from 'reshape'
*		   	   ************************ 

	



								
  if "`keepmisstacks'" == "" | "`fe'" != ""  {						// If `keepmisstacks' NOT optioned OR fixed effects IS optioned ...
	
	 if "`keepmisstacks'"!=""  local dropmisstacks = 0	
	 else local dropmisstacks = 1

	 if ("`fe'"!="")  {												// If fixed effects were optioned
		if ("`fe'"=="_all")  local fe = "`anything'"
		foreach fevar of local fe  {
			capture qui sum `fevar' [aw fw pw/]						// Get weighted mean of each fevar 
			capture local mfevar = r(mean)							// Save in specific local foe each fevar
			`displ' gen `feprefix'`fevar' = `fevar' - `mfevar' 
		}
	 }
		  	 
	 noisily display "." _continue

	 if `dropmisstacks'  {										// If dropping empty stacks ...
		 tempvar stkmiss										// Flag to indicate stack all missing for this context
		 qui egen `stkmiss' = rowtotal(`namelist'), miss		// Set missing for all obs in this (perhaps only) context
		 qui drop if `stkmiss'==.								// Drop stacked observations that are all-missing in this context
		 drop `stkmiss'
	 }
	   
  } //endif keep misstacks | fe
		
	

								
								
								// (4) For final codeblock (following final context) tidy & rename stackMe vars if optioned ...
									

  if `c'==`nc'  {												// If this is the final context
	
	order SMstkid, after(SMunit)								// Tidy results of reshape now performed in `stackmeWrapper'
	egen SMnstks = max(SMstkid), by(SMunit)
	order SMnstks, after(SMstkid)			

	if !`w' noisily display "." _continue
	

	if ("`unitname'"!="")  {									// NO LONGER DOCUMENTED
		if ("`unitname'" != "SMunit")  {
			display as error "SMunit, the default unitname, is used by other stackMe commands. Change anyway?"
*                             12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure "SMunit, the default unitname, is used by other stackMe commands. Change anyway?"
			if _rc==0  {
				rename SMunit `unitname'		 					// This renames a new variable; itemname names an existing variable
				noisily display "'SMunit' changed to `unitname' as identifier of original observations"
				window stopbox note "'SMunit' changed to `unitname' as identifier of original observations"
			}
			else {
				noisily display "'SMunit' is unchanged as identifier of original observations"
				window stopbox note "'SMunit' is unchanged as identifier of original observations"
				local unitname "SMunit"
			}
		} //endif "`unitname'" != "SMunit"

	} //endif "`unitname'"!=""
	
	else local unitname = "SMunit"									// Otherwise store default unitname in optionname
	
	

	if ("`stackid'" != "")  {										// NO LONGER DOCUMENTED
		display as error "SMstkid, the default stackid, is used by other stackMe commands. Change anyway?"
*                         12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "SMstkid, the default stackid name, is used by other stackMe commands. Change it anyway?"
		if _rc==0  {
			rename SMstkid `stackid'		 						// This names a new variable
			noisily display "SMstkid changed to `stackid' as stack identifier recorded in the data label"
			window stopbox note "SMstkid changed to `stackid' as stack identifier recorded in data label"
		}
		else  {
			noisily display "'SMstkid' is unchanged as stack identifier"
			window stopbox note "'SMstkid' is unchanged as stack identifier"
		}
	}

	else local stackid = "SMstkid"									// Otherwise store default stackid in optionname

	
	
	if ("`itemname'"!="")  {										//`itemname' names an existing variable
		capture 
		display as error "`itemname' will override SMstkid, the sequential stack identifier. Ok?"
*                         12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "itemname `itemname' will override SMstkid, the sequential stack identifier. Ok?"
		if _rc==0  {
*			rename SMstkid `itemname'		 						// `SMstkid' was created by genstacks; itemname already existed
*			noisily display "'SMstkid' changed to `itemname' as stack identifier recorded in the data label"
*			window stopbox note "'SMstkid' changed to `itemname' in first word of data label"
		}
		else  {
			noisily display "'SMstkid' is unchanged as stack identifier"
			window stopbox note "'SMstkid' is unchanged as stack identifier"
		}
	}															// Otherwise there is still no itemname (using SMstkid)

	
	if "`totstackname'" != "" &  "`totstackname'"!="SMnstks" {
		display as error "'SMnstks', default stack count, is used by other stackMe commands. Change anyway?"
*                          12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "Other stackMe commands use SMnstks, default totstacks variable. Change anyway?"
		if _rc==0  {
			rename SMnstks `totstackname'
			noisily display "'SMnstks' changed to `totstackname' as count of number of stacks"
			window stopbox note "'SMnstks' changed to `totstackname' as variable holding count of number of stacks"
		}
		else  {
			noisily display "'SMnstks' is unchanged as variable holding count of number of stacks"
			window stopbox note "'SMnstks' is unchanged as variable holding count of number of stacks"
		}
		
	}

	else local totstackname "SMnstks"							// Otherwise store default totstack name in optionname
	

	
	if !`w' noisily display "." _newline						// No 'continue' for final busy dot
	
	
  } //endif `c'==`nc'
  

*	drop `anymiss'												// `anymis', accessed in obs[1], would indicate any all-missing stks
																// (a trick that might come in useful, but not in this application)

																
end //genstacksP

