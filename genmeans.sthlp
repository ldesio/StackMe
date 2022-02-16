{smcl}
{cmd:help genmeans}
{hline}

{title:Title}

{p2colset 5 20 22 0}{...}
{p2col :genmeans {hline 2}}Generates (weighted) context-specific mean values for the variables in varlist 
separately for each defined context{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{opt genmeans} {varlist} 
   [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opth sta:ckid(varname)}}a variable identifying different "stacks", for which means will be 
separately generated if {cmd:genmeans} is invoked after stacking.{p_end}
{synopt :{opt nos:tack}}override the default behavior that treats each stack as a separate context.{p_end}
{synopt :{opt con:textvars}}if specified, names the variables that define each context for which a separate 
(set of) means is to be generated{p_end}
{synopt :{opth pre:fix(name)}}prefix for names of generated variables (default is "m_"){p_end}
{synopt :{opt wei:ght(varname)}}if specified, name of variable determining weight of each respondent{p_end}
{synopt :{opt cwe:ight(varname)}}if specified, name of variable determining the weight for each stack (constant 
across respondents){p_end}

{synoptline}

{title:Description}

{pstd}
{cmd:genmeans} generates a (set of) newvar(s) from a (set of) existing continuous variables, each holding the 
mean value of (each) {it:varlist} variable across all cases in each defined context. Importantly, these means can be 
weighted by the same weights as used for respondents or by weights specific to each stack within each context.

{title:Options}

{phang}
{opth stackid(varname)} if specified, a variable identifying each different "stack" (equivalent to the Stata 
{bf:{help reshape:reshape long}}'s {it:j} index) for which means will be separately generated in the absence 
of the {cmd:nostack} option. The default is to use the "genstacks_stack" variable if the {cmd:genmeans} command 
is issued after stacking.

{phang}
{opt nostack} if present, overrides the default behavior of treating each stack as a separate context (has 
no effect if data are not stacked). This option is not compatible with option {it:cweight}.

{phang}
{opt con:textvars({it:varlist})} if specified, defines the contexts for each of which mean values will be generated 
(same value for all cases in each context).

{phang}
{opt pre:fix({it:name})} if provided, prefix for the generated mean variables (default is to use the prefix "m_") 
at the start of each varname in the varlist for which means are being generated.

{phang}
{opt wei:ght({it:varname})} if specified, specifies the variable used to weight the means being generated, 
treating weights as varying across respondents (the same weighting process used for statistical analyses in Stata).

{phang}
{opt cwe:ight({it:varname})} if specified, specifies the variable used to weight the means being generated, 
treating weights as constant for each stack by context (the same weight for all respondents for each stack in 
each context). Incompatible with option {bf:nostack} if optioned after stacking.

{title:Examples:}

{pstd}Generate means named "m_educ" and "m_income" for the different contexts found in the data.{p_end}

{phang2}{cmd:. genmeans educ income, context(cid year)}{p_end}{break}

{pstd}generate weighted locations of governing parties where weights are derived from votes received (essentially 
a measure of where governments are located in left-right terms). NOTE that the cweight would first have to be 
set to 0 for stacks belonging to non-governing parties.{p_end}

{phang2}{cmd:. genmeans plr, prefix(gov_) context(cid year)} cweight(votepct){p_end}{break}

{title:Generated variables}

{pstd}
{cmd:genmeans} saves the following variables or set of variables:

{synoptset 16 tabbed}{...}
{synopt:m_{it:var1} m_{it:var2} ... (or other prefix set by option {bf:prefix})} a set of context-specific  
means held in variables named p_var1, p_var2, etc., where the names var1, var2, etc. match the original variable 
names in {it:varlist}. Those variables are left unchanged. Used on unstacked data.{p_end}{break}

{synopt:m_{it:vara} [m_{it:varb} ... (or other prefix set by option {bf:prefix})} a (set of different) 
variable(s) holding the mean for each stack in each context for the variables variable in {it:varlist}. Used 
on stacked data.{p_end}
