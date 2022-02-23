{smcl}
{cmd:help genmeans}
{hline}

{title:Title}

{p2colset 6 18 22 2}{...}
{p2col :genmeans {hline 2}}Generates (weighted) context-specific means separately for each context{p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 16 2}
{opt genmeans} {help varlist:{bf:varlist}} [{help weight:{bf:weight}}] [{help if:{bf:if}}]
   [{cmd:,} {it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opth con:textvars(varlist)}}variables defining each context (e.g. country-year){p_end}
{synopt :{opth sta:ckid(varname)}}identifies different "stacks", for which means will be separately 
generated if {cmd:genmeans} is invoked after stacking{p_end}
{synopt :{opt nos:tack}}override the default behavior that treats each stack as a separate context{p_end}
{synopt :{opth mpr:efix(name)}}prefix for names of generated variables (default is "m_"){p_end}
{synopt :{opt nor:eport}}suppress reporting of variables created per context{p_end}

{synoptline}

{title:Description}

{pstd}
{cmd:genmeans} generates mean values of variables in {it:varlist}, separately for each stack and 
context (if specified). These means can be weighted as though deriving from statistical analyses.

{pstd}
The {cmd:genmeans} command can be issued before or after stacking. Means will be generated for 
any variables, whether or not included in a battery of items, separately for each stack (if 
issued after stacking) and separately for each context (if optioned by {bf:contextvars}). 
Resulting means will be constant across units/responces (within items/stacks) and within contexts.


{title:Options}

{phang}
{opt con:textvars({help varlist:{it:varlist}})} if present, variables whose combinations identify different 
contexts (e.g. country and year) for each of which mean values will be generated (same value 
for all units/respondents in each context). By default all units are assumed to belong to the 
same context.

{phang}
{opt pre:fix(name)} if present, prefix for the generated mean variables (default is "m_"). 

{phang}
{opth sta:ckid(varname)} if present, a variable identifying each different "stack" (equivalent to 
the {it:j} index in Stata's {bf:{help reshape:reshape long}} command) for which means will be separately 
generated in the absence of the {cmd:nostack} option. The default is to use the "genmeans_stack" 
variable if the {cmd:genmeans} command is issued after stacking.

{phang}
{opt nos:tack} if present, overrides the default behavior of treating each stack as a separate 
context (has no effect if data are not stacked). This option is not compatible with option 
{it:cweight} because those are weights that apply to each stack.

{phang}
{opt nor:eport} suppress dianostic output regarding variables created for each context.{p_end}



{title:Examples:}

{pstd}The following command, issued before stacking, generates weighted means named "m_educ" "m_income" 
m_plr1 m_plr2 ... m_plr9 for the different contexts found in the data.{p_end}

{phang2}{cmd:. genmeans educ income plr1-plr9 [pw=wt], context(cid year)}{p_end}{break}

{pstd}The following command, issued after stacking, generates weighted mean locations of parties 
in each government and mean closeness to parties in each government. (Note these means are 
effectively placements of the battery objects (in this case governments) just as would be 
produced by {help genplace:{bf:genplace}} if issued with the same set of options; but genplace has 
additional capabilities that {cmd:genmeans} does not have).{p_end}

{phang2}{cmd:. genmeans cls plr [pw=wt] if govpty==1, prefix(gov_) context(cid year)}{p_end}{break}



{title:Generated variables}

{pstd}
{cmd:genmeans} saves the following variables or set(s) of variables:

{synoptset 13 tabbed}{...}
{synopt:m_{it:var1} m_{it:var2} ... (or other prefix set by option {bf:prefix})} a set of context-
specific means held in variables named m_var1, m_var2, etc., where the names var1, var2, etc. 
match the original variable names in {it:varlist}. Those variables are left unchanged. Generated  
for unstacked data.{p_end}

{synopt:m_{it:vara} [m_{it:varb} ... (or other prefix set by option {bf:prefix})} a (set of 
(different) variable(s) holding the mean for each stack in each context for the variable(s) in 
{it:varlist}. Generated for stacked data.{p_end}
