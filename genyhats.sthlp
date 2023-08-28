{smcl}
{cmd:help genyhats}
{hline}

{title:Title}

{p2colset 3 15 15 1}{...}
{p2col :{opt genyhats} {hline 2}}Generates {it:y_hat} affinity measures for multi-lavel (hierarchical) data 
(See StackMe's {help stackme##Genericvariable:Generic Variables} before reading this help-text){p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{opt genyh:ats} {bf:{indepvars} [if][in][weight]} [{cmd:,} {it:options}]
{p_end}
	
		or

{p 8 18}
{opt genyh:ats} {it:ydprefix:} {bf:{indepvars} [if][in][weight], options [} {bf:||} ydprefix: {indepvars} [ {bf:||} ... ]{p_end}


{p 4 4 2}
The first syntax (generally used with stacked 
data) creates a set of so-called "yhat" {help stackme##Affinitymeasures:affinity} measures, one for each {varlist} 
variable, resulting from bivariate analysis of that variable with the variable named in option {opt dep:varname}. 
The second syntax (generally used to identify batteries of variables in unstacked data) creates one yhat variable 
for each ydprefix, the result of regressing the same optioned {opt dep:var} on all of the {indepvars} in the 
associated {varlist} taken together in one multivariate analysis. See {bf:Description}, below, for details.	

{p 4 4 2}Though illustrated with especially appropriate examples, the two syntax formats are interchangeable. Each 
can be used with either stacked or unstacked data. {bf:Speed of execution} can be much increased by grouping 
together varlists that employ the same {opt dep:var} and other options.

{p 4 4 2}With the first syntax, names for generated yhat versions of {varlist} variables are constructed by 
prefixing (using "yi_" or some other prefix set by option {opt yip:refix}) the name of each independent variable 
for which a yhat equivalent is generated. With the second syntax, the names for generated yhats are constructed 
by prefixing (using the "ydprefix" that introduced the multivariate {varlist}) the name of the optioned dependent 
variable for which a yhat equivalent is generated.


{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{p2colset 4 25 27 2}
{p 2}{ul:Estimation options}

{synopt :{opt dep:varname(varname)}}(required) the dependent variable for which 
affinities are to be estimated{p_end}
{synopt :{opt log:it}}invoke a logit model instead of the default linear regression{p_end}
{synopt :{opt adj:ust(mean|constant|no)}}adjust the y_hat by subtracting the mean (default) or 
subtracting the constant term. Alternatively, make no adjustment.{p_end}

{p 2}{ul:Data-structure options}

{synopt :{opt con:textvars(varlist)}}the variables identifying different electoral contexts{p_end}
{synopt :{opt nocon:texts}}override the default behavior that generates y-hats for each 
context separately{p_end}
{synopt :{opt sta:ckid(varname)}}a variable identifying different "stacks", for which y-hats will be 
separately generated if {cmd:genyhats} is invoked after stacking{p_end}
{synopt :{opt nosta:cks}}override the default behavior that treats each stack as a separate context{p_end}


{p 2}{ul:Output and naming options}

{synopt :{opt yip:refix}}the prefix (prefixing each {indepvar}name) for new variable(s) generated by 
bivariate analyses according to syntax 1 (default is to use the prefix "yi_"){p_end}
{synopt :{opt ydpr:efix}}{bf:THERE IS NO ydprefix} option. The {it:yd} prefix for yhats generated by 
multivariate analysis is the prefix that introduces the multivariate {indepvars}{p_end}
{synopt :{opt rep:lace}}drop all {it:indepvars} after the generation of y-hats{p_end}
{synopt :{opt eff:ects(window|rtf|csv|html|no)}}display a summary table of stack-specific effects 
from the regression used to generate a y-hat{p_end}
{synopt :{opt efo:rmat(beta|custom|default)}}use exponent format for coefficients reported 
by the effects() option{p_end}

{p 2}{ul:Diagnostics options}

{synopt :{opt lim:itdiag(#)}}limit diagnostics to the first # contexts processed{p_end}
{synopt :{opt nod:iag}}equivalent to {opt lim:itdiag(0)}{p_end}
{synopt :{opt ext:radiag}}(seldom used) directly output the results of each stack-specific regression.{p_end}

{synoptline}


{title:Description}

{pstd}
{cmd:genyhats} generates (multiple) measures of {help stackme##Affinitymeasures:affinity} between 
{help indepvars} and {help depvars} (see the section on {help stackme##Genericvariable:generic analysis} in the 
{help stackMe} helpfile) for each (list of) {it:indepvar}(s), saving each such measure into a 
corresponding {it:yhat} variable separately for each context

{pstd}
The estimation model can be either multivariate or bivariate. The resulting {it:yhat} names 
are based on the {it:depvarname} for multivariate models (being prefixed by "yd_" or such other 
prefix as may be established by the prefix that introduces a multivariate varlist). Univariate models 
are generally used when multiple {it:indepvars} are each to be linearly transformed into equivalent 
{it:yhat} variables for use in estimation models that attempt to predict {help stackme##Genericvariable:generic} 
{it:depvar}s. Multivariate models are generally used when a generic indicator is wanted for a more 
abstract concept (perhaps social class), to be estimated from a set of (perhaps class-related) {it:indepvars}.

{pstd}
The two syntaxes may be combined, in that any appearance of "||" or "," (or the end of the command) 
causes the previously listed variable(s) to be treated as a separate {varlist}. Any varlist may be 
preceded by a prefix (identified as such by the appearance of a colon at the end of the prefix name) 
that establishes the analysis as multivariate. Such a prefix is used in conjunction with the optioned 
{opt dep:varnmae} to identify the resulting yhat. If there is no such prefix then each variable in the 
{varlist} will define a separate bivariate analysis whose resulting {it:yhats} will be identified by 
the name of the indepvar prefixed by {it:yi} or such other prefix set by {cmd:genyhats}' {opt yip:refix} 
option.

{pstd}
The {cmd:genyhats} command estimates the effect of each (set of) indep(s) on the depvar, separately for 
each stack if the data are stacked (unless {opt nosta:cks} is optioned), and separately for each context 
unless the {opt nocon:texts} option was employed. It uses Stata's {cmd:predict} command to produce predicted 
values of the depvar for each observation. These sets of so-called "y-hats" are each adjusted by subtracting 
the mean from the prediction equation (separately for each stack and context, if present) - 
unless some other adjustment is optioned by using the {cmd:adjust} option - and saved under the 
appropriate variable name as described above. Estimation is by OLS unless {cmd:logit} is optioned.{break}
{space 3}NOTE that, if the y_hat is not adjusted, the stack-specific mean will be included in the estimated y-hats 
creating inconsistencies, as between stacks and contexts, that can result in large anomalies in subsequent 
analyses using these variables. As a result, in published work the choice of subtracting the mean has mostly
been employed (and is the default option in {cmd:genyhats}). However, the option of subtracting the constant 
term is also available and is arguably preferable for hierarchical (multi-level) analyses.

{pstd}
The {cmd:genyhats} command can be issued before or after stacking. If issued after stacking, by default 
it treats each stack as a separate context to take into account along with any higher-level contexts. 
This yields the same y-hat estimates as would have been created for separate unstacked depvars. However, 
the {cmd:nostack} and/or {opt noc:ontexts} options can be employed to force {cmd:genyhats} to ignore 
this default behavior, depending on what makes methodological sense. If issued 
after stacking the command (or relevant {varlist}) need only be used once for the (generic) depvar instead 
of separately for each unstacked depvar. This makes {cmd:genyhats} simpler to use and saves creating a mass 
of temporary variables that would hugely increase the size of the unstacked file.{break}
{space 3}NOTE that when used in subsequent analyses (for instance in regression models) estimated 
coefficients for y-hat variables are not readily interpretable. In the absence of error 
variance and multicolinearity, each coefficient calculated for a y-hat affinity variable 
would be +1.0 (meaning that it perfectly tracked the {depvar} for which it's affinity was 
calculated.) The actual values of these coefficients thus constitute a quasi-measure of 
covariance - like a partial correlation coefficient. However, standard errors (along with 
beta coefficients from OLS) retain their customary meanings.


{title:Options}

{p 2}{ul:Estimation options}{p_end}

{phang}
{opt depvarname(varname)} (required) the dependent variable for which affinities are to be 
estimated.{p_end}

{phang}
{opt logit} if specified, invokes a logit model instead of linear regression (the default).{p_end}

{phang}
{opt adjust(constant|mean|no)} if specified, adjusts the y_hat by subtracting the context mean 
(default) or subtracting the constant term. Alternatively, make no adjustment. Note that, when a logit
model is optioned, the adjustment takes place on propensity values, and then mapped back to probability
values.{p_end}

{p 2}{ul:Data-structure options}{p_end}

{phang}
{opt contextvars(varlist)} if specified, the variables whose combinations of values identify
different electoral contexts (by default all observations are treated as part of a single context).{p_end}

{phang}
{opt nocontexts} if specified, override the default behavior that generates y-hats for each context 
separately.{p_end}

{phang}
{opt stackid(varname)} if specified, a variable identifying different "stacks", for which
y-hats will be separately generated. The default is to use the "genstacks_stack" 
variable if the {cmd:genyhats} command is issued after stacking.{p_end}

{phang}
{opt nostacks} if present, overrides the default behavior of treating each stack as a separate context 
(has no effect if the {cmd:genyhats} command was issued before stacking).{p_end}

{p 2}{ul:Output and naming options}{p_end}

{phang}
{opt yiprefix} if specified, provides a prefix for y-hat affinities generated for each {it:indepvar} 
named using syntax 1 (the bivariate regression syntax). The default is "yi_").{p_end}

{phang}
{opt ydprefix} {bf:THERE IS NO ydprefix} option. The {it:yd} prefix for yhats generated by 
multivariate analysis is the prefix that introduces the multivariate {varlist}. The presence  
of the prefix is the signal that the analysis will be multivariate.{p_end}

{phang}
{opt replace} if specified, drops all original {it:indepvars} for all specified models after the 
generation of y-hats.{p_end}

{phang}
{opt effects(window|rtf|csv|html|no)} if specified, displays a table (in publication format) that 
summarizes the different effects of the same predictors in different stacks. The {cmd:window} option
flushes the table to the standard output, while the other options save the table in an external file,
according to the chosen file format (also used as a suffix to the resulting "yhats" filename). 
By default, z-values are reported, along with significance stars.
The {cmd:eformat()} option can be used to set the display format for reported coefficients.{p_end}

{phang}
{opt eformat(beta|default|custom)} if specified, changes the coefficient reported in 
tables generated by {cmd:effects}. {cmd:efmt()} accepts two types of values: either {cmd:beta} (in order 
to obtain beta coefficients) or any format string that is accepted by the {bf:{help estout##cells:cells()}} 
option of the {cmd:estout} command. As an example, {cmd:efmt(b(fmt(3)star))} displays b coefficients with 
three decimal digits and significance stars. To install estout type 'net sj 14-2 st0085_2'{p_end}

{p 2}{ul:Diagnostic options}{p_end}

{phang}
{opt limitdiag(#)} if specified, limits to # the number of contexts for which diagnostics will be 
reported.{p_end}

{phang}
{opt nodiag} if specified, equivalent to {opt lim:itdiag(0)}.{p_end}

{phang}
{opt extradiag} (seldom used) directly output the results of each individual regression for as many 
variables as specified in {opt lim:itdiag}.{p_end}


{title:Examples}

{phang2}{cmd:. genyhats religs income union educ,} 
{cmd:depvarname(vote) contextvars(cntryid year) stackid(stkid), limitdiag(5)} {p_end}

{pstd}Generate yhat variables named "yi_relig", "yi_income", "yi_union" and "yi_educ" separately for 
each context and stack defined by the variables {it:cntryid year} and {it:stkid}. Display diagnostics for 
the first five of those contexts.{p_end}


{phang2}{cmd:. genyhats class: income union educ,} 
{cmd:depvar(vote) contextvars(cntryid year) stackid(stkid) limitdiag(5)}{p_end}

{pstd}Using the same stacked data, estimate a yhat indicator of social class, operationalized as the optimal 
least-squares estimate of the optioned {it:vote} depver based on income, education and union membership as 
{indepvars}. The resulting yhat will be named "class_vote"{p_end}


{phang2}{cmd:. genyhats partylr1-partylr5, depvar(vote) context(cntryid year) limitdiag(999) || }
{cmd:cuttaxes1-cuttaxes5 || partyid1-partyid5 || class: income union educ}{p_end}

{pstd} Generate yhat variables for three batteries of independent variables in unstacked data, also replicating the 
class-oriented multivariate yhat generation seen in the previous example. This example illustrates, first, that the 
same analysis can be performed on stacked and unstacked data, with the same outcome. When the data in example (3) are 
stacked, the variables employed in this last analysis will be duplicated for each of the parties that define the 
stacks. In example (2) those multiple copies would already exist but the outcome of the data manipulation would 
be the same. The example also illustrates, second, the two different purposes for which yhats might be generated – 
even during the same pass through the same data. As well as the replication, this example also produces yhat measures 
that anticipate data stacking by producing multiple variables that will belong in the same stack after the data have 
been reshaped.{p_end}


{title:Generated Variables}

{synoptset 16 tabbed}{...}
{synopt:yi_{it:var1} yi_{it:var2}}
 ... (or other prefix set by option {bf:yiprefix}) a set of estimated 
{help stackme##Affinitymeasures:affinity measures} derived from variables {it:var1, var2}, etc., by means of univariate 
analyses in which those variables were each used to predict a {depvar} named in the {cmd:genyhats} {opt depvar} option. 
Variables {it:var1, var2}, etc., are left unchanged (unless replaced).{p_end}

{synopt:{it:class_vote religs_vote} ... } a set of estimated 
measures with names {it:class_vote, religs_vote}, etc., where the prefixes "class", etc., were set by the 
{it:depvar:} prefix at the start of the {varlist} that named the {indepvars} for a multivariate analysis, and where 
the name "vote" matches the name of the optioned dependent variable. That variable is left unchanged, unless replaced 
(be careful not to replace a variable that will be used as a depvar in subsequent varlists or subsequent calls on 
{cmd:genyhats}.{p_end}

{pstd}
The first example features variables with numeric suffixes, suggesting that the resulting yi_-prefixed yhat variables 
were created in unstacked data. The second example is more likely to be seen with stacked data, where numeric suffixes 
are unusual.{p_end}

