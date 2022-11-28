{smcl}
{cmd:help geniimpute}
{hline}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :geniimpute {hline 2}}Incremental simple (or multiple separate) imputation(s) of a set of variables{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{opt geniimpute} {varlist}
   [{cmd:,} {it:options}]   [ {bf:||}   {varlist} [{cmd:,} {it:options} ...] ]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:{ul:Imputation options}}
{synopt :{opt add:itional(varlist)}}additional variables to include in the imputation model{p_end}
{synopt :{opt sel:ected}}selects variables from the {it:additional} list only if they have no more 
missing data than the {it:varlist} variable with most missing data{p_end}
{synopt :{opt noi:nflate}}do not inflate the variance of imputed values to match the variance of original 
item values (default is to add random perturbations to these values, as required){p_end}
{synopt :{opt rou:ndedvalues}}round each imputed value, after inflation, to the nearest integer (default 
is to leave imputed values unrounded){p_end}
{synopt :{opt min:ofrange(#)}}minimum value of the imputed value range for all {it:varlist} variables{p_end}
{synopt :{opt max:ofrange(#)}}maximum value of the imputed value range for all {it:varlist} variables{p_end}
{synopt :{opt bou:ndedvalues}}bound the range of imputed values for each {it:varlist} variable to the same 
bounds as found for that variable's unimputed values{p_end}
{syntab:{ul:Data-structure options}}
{synopt :{opt con:textvars(varlist)}}a set of variables identifying different electoral contexts 
(by default all cases are treated as part of the same context){p_end}
{synopt :{opt sta:ckid(varname)}}a variable identifying different "stacks" for which values will be 
separately imputed if {cmd:geniimpute} is issued after stacking{p_end}
{synopt :{opt nos:tack}}override the default behavior that treats each stack as a separate context{p_end}
{syntab:{ul:Output and naming options}}
{synopt :{opt ipr:efix(name)}}prefix for generated imputed variables (default is "i_"){p_end}
{synopt :{opt mpr:efix(name)}}prefix for generated variables indicating original missingness
of a variable (default is "m_"){p_end}
{synopt :{opt kee:pmissing}}keeps all generated variables indicating original missingness (otherwise dropped)
of a variable (default is "m_"){p_end}
{synopt :{opt rep:lace}}drops all original variables in {it:{it:varlist}} after imputation{p_end}

{syntab:{ul:Diagnostics options}}
{synopt :{opt lim:itdiag(#)}}number of contexts for which to display diagnostics (these can 
be quite voluminous) as imputation progresses (default is to display diagnostics for all contexts){p_end}
{synopt :{opt ext:radiag}}extend any displayed diagnostics with extra detail{p_end}

{synoptline}

{title:Description}

{pstd}
The command name "geniimpute" has two 'i's that stand for "inflated imputed" because imputed values of 
variables that were missing before imputation have, by default, their variance inflated to match the 
variance of the non-missing values for the same variable, thus emulating the data expected by Stata's 
{help mi:{cmd:mi}} suite of commands. Though {cmd:geniimpute} can impute (optionally variance-inflated) 
missing values for a single variable (by calling Stata's {cmd:impute} command and augmenting the output 
from that command according to various options described below) its primary function is to impute 
multiple variables contained in a battery (generally the items that constitute separate answers to a 
single survey question) according to an incremental procedure which - if required - is applied 
separately to each electoral context identified by {cmd:{it:contextvars}}, as follows:

{p 6 6 2}1) Within each context, observations are split into groups, based on the number of missing items.
Observations for which only one variable has a missing value are processed first, and so on.

{p 6 6 2}) Within each of the above groups, variables are ranked according to the number of missing 
observations. Variables with fewer missing observations are processed first, and so on.

{p 6 6 2}3) According to the order defined in step 2 (and within each group defined in step 1),
variables are imputed through an augmented simple imputation (based on Stata's {cmd:impute} command).

{pstd}
This implements the incremental nature of the procedure.
Since observations with fewer missing variables are imputed first, and (within each group) items
with fewer missing observations are imputed first,
later imputations (that have to impute more data) will use a more complete (partially imputed) dataset.

{pstd}
The imputation model is based on all valid values of variables in {it:varlist},
plus all variables specified in the {cmd:additional()} option, which - understandably - 
would be crucial for imputating those observations where all variables in {it:varlist} 
have missing values (but there might be theoretical reasons for basing imputation only 
on the values of other members of a battery).

{pstd}
Please be aware that the sample used in the imputation model is the whole electoral 
context and not only a restricted group of cases defined in step 1.

{pstd}
NOTE that the number of independent variables upon which to base the imputation (the total of 
{it:{bf:varlist}} and {cmd:additional}) is limited to 30 because that is the limit for Stata's {cmd:impute} 
command. This limitation might lead the user to prefer to issue the {cmd:geniimpute} command after 
{help genstacks:{cmd:genstacks}} and {help genyhats:{cmd:genyhats}} have reduced the number of indeps in the 
dataset.

{p 6 6 2}4) The output of Stata's {cmd:impute} command is then optionally augmented by inflating the variance of 
of imputed item values to match the variance of original item values, as recommended in the literature. 
If this is not wanted then the option {cmd:noinflate} should be employed.

{p 6 6 2}5) Imputed values should approximate values observed in the data, but are seldom the same as those 
values. Discrete intervals can be enforced if data are {cmd:rounded}. Predicted values beyond the rage 
observed in the data can survive such rounding but can be eliminated by using the {cmd:minofrange()} 
and/or {cmd:maxofrange()} options to constrain imputed values. Applying such constraints can be useful when a 
battery of analogous items is being imputed. This may suggest specifying multiple variable lists (separated 
by "||"), each accompanied by differen options. Options for subsequent variable lists need not be specified 
if unchanged. When imputing a set of heterogeneous variables 
(not members of a single battery) imputed values of each separate variable can be {cmd:bounded} by the 
minimum and maximum observed for that member of the heterogenious set. By default no constraints are applied.

{pstd}
The {cmd:geniimpute} command can be issued before or after stacking. If issued after stacking, by default it 
treats each stack as a separate context to take into account along with any higher-level contexts. However, 
the {cmd:nostack} option can be employed to force {cmd:geniimpute} to ignore stack-specific contexts. In 
addition, the {cmd:geniimpute} command can be employed with or without distinguishing between higher-level 
contexts, if any, (with or without the {cmd:contextvars} option or omitting certain variable(s) from that 
option), depending on what makes methodological sense.{break}


{title:Multiple Imputation}

{pstd} The data generated by {cmd:geniimpute} can be seen as analageous to multiply-imputed data if the 
multiple contexts, in each of which missing data are replaced with inflated imputations, are viewed as 
replications of what (in Stata's {help mi:{bf:mi}} terminology) could be viewed as an an imaginary m=0  
dataset. When {cmd:iimpute}d 
data are processed by appropriate multi-level estimation commands, the object is precisely to render 
individual contexts as random replications of one-another; and correctly estimated coefficients from such 
commands depend on achieving such quasi-randomization. The same quasi-randomization makes the different 
contexts essentially equivalent to randomized replications of one-another, as they would be when using 
multiple imputation proper (for example, using Stata's {help mi:{bf:mi}} suite of commands). A 
multiply-imputed dataset can of course be created by Stata's {help mi:{bf:mi impute}} and the suite of commands 
available for mi-imputed data does include many of the (xt and other) multi-level commands suited for 
estimation with multi-level data. But if those commands are appropriate for multi-level mi-imputed data 
then they are equally appropriate for multi-level genii-imputed data.

{pstd} NOTE that, if the data need to be replicable, each dataset to be used in 
multiple imputation will need to be produced by a separate call on {cmd:geniimpute} that would follow 
a Stata {help set seed:{bf:set seed}} command; and those seeds would need to be recorded in Stata's data 
{help note:{bf:note}}s or elsewhere.


{title:Options} {sf:(none of these are required)}

{p 2}{ul:Imputation options}{p_end}

{phang}
{opth additional(varlist)} if specified, additional variables to include in the imputation model 
beyond those in {it:varlist}. These additional variables will not have any missing values imputed.

{phang}
{opt selected} if specified, selects among {it:additional} variables only those with no more 
missing values than the {it:varlist} variable with the largest number of missing values)

{phang}
{opt noinflate} if specified, cancels the random inflation of imputed values' variance, which 
otherwise happens by default{p_end}

{phang}
{opt roundedvalues} if specified, round each final value (after inflation, if any) to the closest integer 
(default is to leave values unrounded){p_end}

{phang}
{opth minofrange(#)} if specified, minimum value of the item range used for constraining imputed 
value(s). {bf:Note} that this option constrains the 
value(s) used for imputing all variables in varlist to the same minimum and/or maximum (useful 
when imputing missing values for batteries of variables that should all have the same range).{p_end}

{phang}
{opth maxofrange(#)} if specified, maximum value of the item range used for constraining imputed
value(s). {bf:Note} that this option constrains the 
value(s) used for imputing all variables in varlist to the same minimum and/or maximum (useful 
when imputing missing values for batteries of variables that should all have the same range).{p_end}

{phang}
{opt boundedvalues} if specified, bounds the minimum and maximum of imputed values to the  
min/max found in unimputed values of the same variable. This overrides minofrange/maxofrange 
for specific variables if the bounded range is smaller. Seldom used with variable batteries.{p_end}

{p 2}{ul:Data-structure options}{p_end}

{phang}
{opth contextvars(varlist)} if specified, variables whose combinations identify
different electoral contexts (default is to treat all cases as part of the same context) 

{phang}
{opth stackid(varname)} if specified, a variable identifying different "stacks" for which values will be 
separately imputed in the absence of the {cmd:nostack} option. The default is to use the "genstacks_stack" 
variable if the {cmd:geniimpute} command is issued after stacking.

{p 2}{ul:Output and naming options}{p_end}

{phang}
{opt nostack} if present, overrides the default behavior of treating each stack as a separate context (has 
no effect if the {cmd:geniimpute} command is issued before stacking).

{phang}
{opth iprefix(name)} if specified, prefix for names of imputed variables (default is to prefix each 
original {it:varname} with "i_") when naming output variables.{p_end}

{phang}
{opth mprefix(name)} if specified, prefix for names of variables that indicate the original
missingness of each variable in {it:varlist} (default is "m_"). These generated variables are coded 
0 if the {it:varlist} variable was not missing, 1 if it was missing (and its {bf:iprefix} version has been 
assigned a non-missing value by {cmd:geniimpute}).{p_end}

{phang}
{opt keepmissing} if specified, keeps all {cmd:mprefix*} variables indicating original missingnes 
(by default these are dropped after imputed vars have been created).{p_end}

{phang}
{opt replace} if specified, drops all original variables for which imputed versions have been created 
(default is to keep original as well as new variables). TAKE CARE NOT TO DROP VARIABLES NEEDED FOR A 
SUBSEQUENT IMPUTATION GOVERNED BY A SEPARATE VARLIST! Doing so will produce a "{bf:{it:variable} not found}" 
(perhaps along with an error 999) when processing that varlist.{p_end}

{p 2}{ul:Diagnostic options}{p_end}

{phang}
{opth limitdiag(#)} if specified, limits the number of contexts for which diagnostics are 
displayed to # (default is to display diagnostics, which can be quite voluminous, for all 
contexts){p_end}

{phang}
{opt extradiag} if specified, extends the detail of the diagnostics, when displayed{p_end}


{title:Examples:}

{pstd}The following command imputes a battery of PTVs whose names begin with {it:ptv}, in a dataset 
where observations are nested in contexts defined by {it:cid}. The imputation model is based only 
on the PTV variables. Imputed values will be rounded to the nearest integer between 0 and 10. The 
data are assumed to be not already stacked.{p_end}

{phang2}{cmd:. geniimpute ptv*, context(cid) min(0) max(10) round} {p_end}{break}


{pstd}The following command imputes variables {it:ptv} and {it:lrresp} in a dataset that
had already been stacked and where observations are nested in contexts defined by {it:cid}. The 
imputation model is based on these variables plus a variety of y-hat affinity varlables and one
party-level variable (seats). Imputed values will not be constrained in any way. Such a command
might well be issued prior to a call on gendist to create euclidean distances between lrresp
(if that was left-right respondent location) and a battery of party location variables.{p_end}

{phang2}{cmd:. geniimpute ptv lrresp, additional(y_class-y_churchatt seats) contextvars(cid)}{p_end}{break}


{pstd} The following command imputes a battery of ptv variables with range 0-10 and a battery of 
party identification scores with a range 1-7. All other options are the same for both 
imputations. The stackid in this example is specified with a varname that is different from the 
default name ("stackid").

{phang2}{cmd:. geniimpute ptv*, con(cid) stackid(stk) min(0) max(10) || pid*, min(1) max(7)}{p_end}{break}


{title:Generated variables}

{pstd}
{cmd:geniimpute} saves the following variables and variable sets:

{synoptset 20 tabbed}{...}
{synopt:i_{it:name1} i_{it:name2} ...} a set of variables with names matching the original variables
(which are left unchanged) for which missing data has been imputed.{p_end}
{synopt:m_{it:name1} m_{it:name2} ...} a set of dummy variables indicating whether each specific variable was 
imputed in a specific observation (i.e. was originally missing).{p_end}

{phang}
NOTE: The user can add counts of missing/nonmissing values for any set of variables (whose missing values 
have or have not been replaced with imputed values) by using STATA's {bf:rowmiss} and {bf:rownonmiss} functions 
within its {help egen:{bf:egen}} command.{p_end}
