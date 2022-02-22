/*
REQUIRES vallist							// Why? Seems to work fine like this, and we don't want
*/									//  users to have to acquire any external ado files
	
capture program drop gendummies
program define gendummies
	version 9.0
	syntax varlist, [PREfix(name)] [INCludemissing]
	local varlist = "`varlist'"

	local nvars = wordcount("`varlist'")
	forvalues i = 1/`nvars'  {
		local varname = word("`varlist'",`i')
		confirm numeric variable `varname' 
		quietly levelsof `varname', local(values)
		
		local thePrefix = "`varname'"				// Here `prefix' is a stubname
		if ("`prefix'"!="")  {
			local thePrefix = "`prefix'"
		}

		foreach v in `values'  {
			//display `v'
			capture drop `thePrefix'`v'
			gen `thePrefix'`v' = (`varname'==`v')
		
			local labellist : value label `varname'
			local label : label (`varname') `v'
		
			label variable `thePrefix'`v' "`varname'==`v' `label'"
		
		
			if ("`includemissing'"=="includemissing")  {
				foreach var of varlist `thePrefix'*  {
					if ("`var'"!="`varname'")  {
						replace `thePrefix'`v' = 0 if `varname'>=.
					}
				}
			}
			else {
				replace `thePrefix'`v'=. if `varname'>=.
			}
		} // next `v'
	} // next `i'
end
