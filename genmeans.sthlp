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
{synopt :{opth pre:fix(name)}} prefix for names of generated mean variables (default is "m_" prefix){p_end}
{synopt :{opt con:textvars}} if specified, names the variables that define each context for which a separate 
(set of) means is to be derived{p_end}
{synopt :{opt wei:ght(varname)}} if specified, name of variable determining weight of each respondent{p_end}
{synopt :{opt cwe:ight(varname)}} if specified, name of variable determining the weight for each stack (constant 
across respondents){p_end}

{synoptline}

{title:Description}

{pstd}
{cmd:genmeans} generates a (set of) newvar(s) from a (set of) existing continuous variables, each holding the 
mean value of (each) variable across all cases in each defined context. Importantly, these means can be 
weighted by the same weights as used for respondents or by weights specific to stacks and contexts (see 
under {bf:Options} and {bf:Examples}.

{title:Options}

{phang}
{opt pre:fix({it:name})} if provided, prefix for the generated mean variables (default is to use the prefix "m_") 
followed by the name(s) of the variable(s) for which means are being venerated.

{phang}
{opt con:textvars({it:varlist})} if specified, defines the contexts for each of which mean values will be generated 
(same value for all cases in each context).

{phang}
{opt wei:ght({it:varname})} if specified, specifies the variable used to weight the means being generated, 
treating weights as varying across respondents (the usual weighting process in Stata).

{phang}
{opt cwe:ight({it:varname})} if specified, specifies the variable used to weight the means being generated, 
treating weights as constant for each stack by context (the same weight for each respondent in each context).

{title:Examples:}

{pstd}Generate means named "m_educ" and "m_income" for the different contexts found in the data.{p_end}{break}

{phang2}{cmd:. genmeans educ income, context(cid year)}{p_end}

{pstd}generate weighted locations of governing parties where weights are derived from votes received (essentially 
a measure of where governments are located in left-right terms).{p_end}{break}

{phang2}{cmd:. genmeans plr, prefix(gov_) context(cid year)} cweight(votepct){p_end}

{title:Generated variables}

{pstd}
{cmd:genmeans} saves the following variable or set of variables:

{synoptset 16 tabbed}{...}
{synopt:m_{it:var1} m_{it:var2} ... (or other prefix set by option {bf:prefix})} a set of context-specific  
means held in variables named p_var1, p_var2, etc., where the names var1, var2, etc. match the original variable 
names. Those variables are left unchanged.{p_end}
