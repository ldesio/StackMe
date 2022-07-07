{smcl}
{cmd:help gendummies}
{hline}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :gendummies {hline 2}}Generates set(s) of dummy variables with suffixes taken from category codes{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{opt gendummies} {[stub:]{help varname} [[stub:]{help varname} . . .]} [{cmd:,} {it:options}]

or

{p 8 16 2}
{opt gendummies} {varname} [{cmd:,} {it:options}]  



{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt inc:ludemissing}} if specified, include missing values as zeros{p_end}
{synopt :{opth pre:fix(name)}} (only with second syntax) prefix for generated dummy variables (default is to use 
the name of the variable from which the dummies are generated){p_end}


{title:Description}

{pstd}
{cmd:gendummies} generates set(s) of (optionally {it:stub}-prefixed) dummy variables from categorical variable(s), 
using as suffixes the codes actually found in the data, with the option to generate all-zero dummy variables for 
any {it:varname} with missing value(s). Any variable for which a stub is not specified will be named with the name 
of the variable whose categories are being expanded into separate dummies.

{pstd}
NOTE ON MULTIPLE BATTERIES: {cmd:gendummies} uses the codes found in the data as suffixes for the generated 
variables, thus permitting users to ensure consistent codes across disparate batteries of responses (e.g. behaviours, 
attitudes, etc.) relating to the same items (e.g. political parties). This is in contrast to Stata's {cmd:tab1}, 
which uses sequential suffixes starting at the number 1 for the generated variables, no matter how those variables 
were coded. 

{pstd}
{bf:See also} the warning in the "SPECIAL NOTE ON MULTIPLE BATTERIES" at the end of the {bf:Description} 
section of {cmd:stackMe}'s help text for the {help gendist} command. That warning applies equally to {cmd:gendummies}.


{title:Options}

{phang}
{opt inc:ludemissing} if specified, missing values for {it:varname} will be coded as all zeros.

{phang}
{opt pre:fix(name)} (only with second syntax) optional prefix for the generated dummy variables (default is to use 
as prefix the name(s) of the variable(s) from which the dummies are being generated). This format is retained from 
earlier versions of {cmd:gendummies} to provide for legacy user coding.

{title:Examples:}

{phang2}{cmd:. gendummies relig:rdenom educ gender:sex }{p_end}

{pstd}Generate dummies named "religX", "educX" and "genderX" for different values (X) found in the data for the 
variables {it:rdenom}, {it:educ} and {it:sex}; missing values on the original variable(s) will produce missing values 
on all of the corresponding dummy variables.{p_end}

{phang2}{cmd:. gendummies relig educ sex, includemissing}{p_end}

{pstd}Generate dummies for different values of the same variables as in the first example, but naming all of these 
by appending to the original variable names suffixes identifying the values found; missing values on any of these 
variables will coded zero on all the corresponding dummy variables.{p_end}

