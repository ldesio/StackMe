capture program drop geniimpute

program define geniimpute

	version 13.0												// geniimpute version 0.92, July 2022
	
	// This program is a front-end for geniimputeP (originally 'iimpute'), calling geniimpute once for 
	// each user-supplied varlist, that varlist being followed (optionally followed in the case of 
	// varlists beyond the first) by a list of options. Options remain in effect for varlists after 
	// the first unless superceded by any newly (re-)specified options appended to those varlist(s).
	
	// The 0.92 'geniimputeP' implements a new logic that calls 'iimpute_body' once for each context for 
	// each varlist instead of once for each varlist, as previously. Making the program byable was tried 
	// and abandoned; so this version preserves the whole dataset and drops all except each context 
	// in turn. This saves processing the entire dataset (all contexts) for each of the calls on impute. 
	// `geniimpute' and `geniimpute_body' are largely unchanged (except that much of the functionality 
	// of iimpute_body has been transferred to what is now geniimputeP, but called multiple times from 
	// geniimputeP (once for each context-stack). The transferred functionality includes everything needed 
	// to set up for looping through contexts. Some functionality has been added to service the new options 
	// `bounded' and `selected'. Bounded does for a heterogenious variable list what `minofrange' and 
	// `maxofrange' do for a variable list that defines a battery of items. `Bounded' takes the minimum 
	// and maximum values for each variable from the minimum and maximum found empirically in the data 
	// for that variable. Selected chooses from among `additional' variables only those with at least as 
	// many valid cases as the valid cases for the variable in `varlist' with minimum valid cases. See 
	// the new helpfile for details. What was the undocumented `log' option has been renamed `extradiag'. 
	// Diagnostic displays have been redesigned to produce only one line of text per variable per context.
	// Changes about which I am doubtful or want to flag for extra attention are marked "***" in the right 
	// margin of each dofile.
	
*set trace on	

	foreach c in additional contextvars stackid opt1 opt2 opt3  {
		global `c' = ""										// Empty any globals that might have been left when a previous invocation failed
	}

	
	gettoken prepipes postpipes : 0, parse("||")			// Command line is in `0' for first loop, `postpipes' thereafter
	
	while ("`prepipes'"!="")  {
		
		gettoken precomma opt : prepipes, parse(",")		// Put all following comma (up to "||", if any) into `opt'
															// Any options following "||" will replace any of same name set previously

/*															// This code structure permits later requirements such as this
	if ("`options'"=="")  {									//  one (commented-out for now)															***
		display as error("Some options are required for (first) varlist")
		exit
	}

*/
		local 0 = "`prepipes'"								// Put `prepipes' into `0' so it can be parsed					
		
		syntax varlist, ///									// Syntax is post-processed in geniimputeP and geniimpute_body
		[ADDitional(varlist) CONtextvars(varlist) BOUndvalues MINofrange(integer 999999999) MAXofrange(integer -999999999)] ///
		[IPRefix(name)] [MPRefix(name)] /*[MCOuntname(name)] [MIMputedcountname(name)]*/ [LIMitdiag(integer -1)] [EXTradiag] ///
		[ROUnd] [STAckid(varname)] [NOStacks] [DROpmissing] [NOInflate] [REPlace]
		
*set trace off				

		geniimputeP `varlist' `opt'							// One call on geniimputeP for each varlist (there is a leading comma in `opt')
		
															
															// Is there another varlist, maybe ending in "||", in `postpipes'?
												
		if "`postpipes'" != "" {							// `postpipes', if any, will start with "||"
		
			local postpipes = stritrim(trim(substr("`postpipes'",3,.)))
			gettoken prepipes postpipes : postpipes, parse("||")
			display _newline "|| `prepipes'"
			
		}
		else local prepipes = ""

				
*set trace off
	} //next while 											// While checks that 'postpipes' is not empty

	
	global opt1 = ""										// Empty the global strings
	global opt2 = ""
	global opt3 = ""
	global additional = ""
	global contextvars = ""
	global stackid = ""
  

  
end
