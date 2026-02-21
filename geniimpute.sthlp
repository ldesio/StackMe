*! Feb 21'25

{smcl}
{cmd:help geniimpute}
{hline}

{title:Title}

{p2colset 5 19 19 2}{...}
{p2col :{bf:geniimpute} {hline 2}}Incremental simple (or multiple separate) imputation(s) of a set of variables{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{opt genii:mpute} (stacked) {varlist} {ifin} {weight} {bf:, options}

{p 12 12 2}
Generate imputed values with which to plug missing data observations for each member of {varlist}, based on 
estimation models that include other {varlist} members (along with optioned additional variables that do not 
themselves have their missing values plugged). The resulting imputed outcomes will be named by prefixing 
(with "ii_" or such other string as set by option {opt ipr:efix}) each outcome name.

{p 12}
or

{p 8 19 2}
{cmdab:genii:mpute} (unstacked) [ii_][{it:addvars}:]{varlist} {ifin} {weight} [ || {break} 
                    (unstacked) [ii_][{it:addvars}:]{varlist} {weight} ]    [  ... ]   || {break}
					(unstacked) [ii_[]{it:addvars}:]{varlist} {weight} {cmd:,} {opt options} 

{p 12 12 2}
Generate imputed values just as with the first syntax, but with additional variables being specified in 
a prefixing varlist instead of with an option. This allows the additional list to be varied from varlist 
to varlist, making this syntax better suited to use with unstacked data (see below).

{p 4 4 2}Though illustrated with especially appropriate examples, the two syntax formats are interchangeable. 
Each can be used with either stacked or unstacked data. But {bf:speed of execution} can be much increased by grouping 
together varlists that employ the same options. In that case ', options...' should appear after the final {varlist}; 
[if] or [in] should follow the first {varlist}; weights can follow any or all {varlist}s;{p_end}

{p 4 4 2}Missing data must be coded according to standard {bf:Stata} conventions. Datasets using other conventions 
should first be pre-processed using {bf:Stata}'s {help mvdecode} command.

{p 6 8 2}{bf:If the data are not yet stacked:} each varlist should enumerate members of the one battery for 
which missing data imputations will be separately generated. Variables that are not battery members can be added as 
appropriate.{p_end}

{p 6 8 2}{bf:If the data are already stacked:} input variables should be those that will be included in a   
imputation-estimation model, whatever their status before stacking. Imputed values are calculated separately 
by stack and context (unless optioned otherwise).{p_end}

{p 4 4 2}aweights, fweights, iweights, and pweights are allowed; see {help weight}.


{synoptset 19 tabbed}{...}
{synopthdr}
{synoptline}

{p 2}{ul:Imputation options}

{p2colset 5 22 20 2}{synopt :{opt add:vars(varlist)}}additional variables to include in the imputation model,  
if they do not preceed the initial colon of a syntax 2 varlist{p_end}
{synopt :{opt sel:ected}}selects variables from the {opt additional} list only if they have no more 
missing values than the {bf:{varlist}} variable with most missing data{p_end}
{synopt :{opt noi:nflate}}do not inflate the variance of imputed values to match the variance of original 
item values (default is to add random perturbations to these values, as required){p_end}
{synopt :{opt set:seed}}(incompatible with {opt noi:nflate}) set the "seed" value for Stata's {help runiform}
command{p_end}
{synopt :{opt rou:ndedvalues}}round each imputed value, after inflation, to the nearest integer (default 
is to leave imputed values unrounded){p_end}
{synopt :{opt min:ofrange(#)}}minimum value of the imputed value range for all {it:varlist} variables{p_end}
{synopt :{opt max:ofrange(#)}}maximum value of the imputed value range for all {it:varlist} variables{p_end}
{synopt :{opt bou:ndedvalues}}bound the range of imputed values for each {it:varlist} variable to the same 
bounds as found for that variable's unimputed values{p_end}

{p 2}{ul:Data-structure options}

{synopt :{opt con:textvars(varlist)}}{generally unspecified) a set of variables identifying the different 
electoral contexts within which imputations will be separately generated (required if the default, recorded 
as a 'data characteristic' by command {cmdab:SMcon:textvars}, is to be overriden){p_end}
{synopt :{opt nos:tacks}}override the default behavior that treats each stack as a separate context{p_end}
{synopt :{opt nocon:texts}}ignore any previously-established context variables{p_end}

{syntab:{ul:Output and naming options}}

{synopt :{opt ipr:efix(name)}}prefix for generated outcome variables (default is "ii_"){p_end}
{synopt :{opt mpr:efix(name)}}prefix for generated outcome variables indicating original missingness
of a variable (default is "im_"){p_end}
{synopt :{opt kee:pmissing}}keeps all generated outcome variables indicating original missingness (otherwise dropped){p_end}
{synopt :{opt rep:lace}}drops all original variables in (each) {varlist} after imputation{p_end}

{syntab:{ul:Diagnostics options}}

{synopt :{opt lim:itdiag(#)}}number of contexts for which to display diagnostics as imputation progresses 
(default is to display diagnostics for all contexts){p_end}
{synopt :{opt nod:iag}}equivalent to {opt lim:itdiag}(0){p_end}
{synopt :{opt ext:radiag}}extend any displayed diagnostics with extra detail{p_end}

{synoptline}

{title:Description}

{pstd}
The command name {cmdab:genii:mpute} has two 'i's that stand for "imputed inflated" because each variable's  
observations that were missing before imputation have, by default, their plugged values randomly 
inflated to match the variance of the non-missing values of the same variable, thus emulating the data 
expected by Stata's {help mi} suite of commands. Though {cmd:geniimpute} can impute (optionally 
variance- inflated) missing values for a single variable (by calling Stata's obsolete but still available 
{cmd:impute} command and augmenting the output from that command according to various options described 
below) its primary function is to impute multiple variables contained in a {help stackme_battery} (generally  
the items that constitute separate answers to a single survey question). Imputation follows an incremental 
procedure which - by default - is applied separately to each electoral context identified by 
{opt contextvars}, as follows:

{p 6 6 2}1) Within each context, observations are split into groups based on the number of missing items.
Observations for which only one variable has a missing value are processed first, and so on.

{p 6 6 2}2) Within each of the above groups, variables are ranked according to the number of missing 
observations. Variables with fewer missing observations are processed first, and so on.

{p 6 6 2}3) According to the order defined in step 2 (and within each group defined in step 1),
variables are imputed through an augmented simple imputation (based on Stata's (superceded) {cmd:impute} command).

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
on the values of other members of the same battery).

{pstd}
NOTE (1) that the sample used in the imputation model is the whole electoral 
context and not only a restricted group of observations defined in step 1.

{pstd}
NOTE (2) that the number of independent variables upon which to base the imputation (the total of 
{varlist} and {cmd:additional}) is limited to 30 because that is the limit for Stata's {cmd:impute} 
command. This limitation might lead the user to prefer to issue the {cmd:geniimpute} command after 
{help genstacks} and {help genyhats} have reduced the number of indeps in the dataset.

{p 6 6 2}4) The output of Stata's {cmd:impute} command is then, by default, augmented by inflating the variance 
of imputed item values to match the variance of original item values, as recommended in the literature. 
If this is not wanted then the option {cmd:noinflate} should be employed.

{p 6 6 2}5) Imputed values should, in principle. approximate the values observed in the data, but are seldom 
the same as those values. Discrete intervals can be enforced if imputed values data are {cmd:rounded}. Predicted values 
beyond the rage observed in the data might survive such rounding but can be eliminated by using the {cmd:minofrange()} 
and/or {cmd:maxofrange()} options to constrain imputed values. Applying such constraints can be useful when a 
battery of analogous items is being imputed. This might suggest specifying multiple variable lists (separated 
by "||"), each accompanied by different options (but speed of execution can be much increased if options are 
left unchanged for multiple varlists, with minimum and maximum constraints being applied separately using 
Stata's {help replace} {help if}...). When imputing a set of heterogeneous variables (not members of a single 
battery) imputed values of each separate variable can be {cmd:bounded} by the minimum and maximum observed 
for that member of the heterogenious set (thus producing imputations whose bounds vary appropriately even 
without new options being applied). By default no constraints are employed.

{pstd}
The {cmd:geniimpute} command can be issued before or after stacking. If issued after stacking, by default it 
treats each stack as a separate context to take into account along with any higher-level contexts. However, 
the {cmd:nostack} option can be employed to force {cmd:geniimpute} to ignore stack-specific contexts. In 
addition, the {cmd:geniimpute} command can be employed with or without distinguishing between higher-level 
contexts, if any, (with or without the {cmdab:nocon:texts} option or omitting certain variable(s) from that 
option), depending on what makes methodological sense.{break}


{title:Multiple Imputation}

{pstd}
In an important sense, iimputation of missing values in multiple contexts already constitutes a multiple 
imputation procedure since multiple replications of the data (from different contexts) are provided with 
(different) randomly inflated plugging values for missing observations. Functionally this replicates what 
is done with datasets from a single context where the multiple replications have been simulated instead 
of being found empirically. If this is not considered adequate, it is possible to iimpute multiple different 
datasets, each one separately saved to be later imported into Stata's {help mi}. Alternatively, Stata's 
{help mi} suite of commands can be employed with data that have been pre-processed by {cmd:StackMe}; but 
this would result in an (arguably unnecessary) m-fold increase (where `m' is the number of replications 
produced by Stata's {help mi}) in the size of what might be an already very large dataset.

{pstd} NOTE that, if the data need to be replicable, each dataset to be used in multiple imputation will 
need to be produced by a separate invocation of {cmd:geniimpute} that would follow a Stata {help set seed} 
command; and those seeds would need to be recorded in Stata's data {help note}s or elsewhere.



{title:Options} {sf:(none of these are required)}

{p 2}{ul:Imputation options}{p_end}

{phang}
{opth addvars(varlist)} if specified, additional variables to include in the imputation model beyond 
those in {it:varlist}. These additional variables will not have any missing values imputed. In syntax 
2 these additional variables can be specified before a colon that introduces the variables for which 
missing values are to be imputed. Although these might be seen as prefix variables, because there can 
be more than one of them they may not themselves be prefixed with string-prefixes.

{phang}
{opt selected} if specified, selects among {it:additional} variables only those with no more 
missing values than the {it:varlist} variable with the largest number of missing values)

{phang}
{opt setseed} (incompatible with {opt noi:nflate}) if specified, provides a "seed" value for Stata's 
{help runiform} command. The number should ideally be chosen randomly from all integer values from 1 
to 2,147,483,647. {cmd:geniimpute} will record the selected value in the last component of the first 
word of the data label for the currently {help use}d dataset. Note that replicating the iimputed 
values of variables generated by {cmd:geniimpute} using this seed depends entirely on using precisely 
the same {cmd:geniimpute} command-lines in precisely the same order with all variables referenced by 
those commands having precisely the same values. In practice this calls for using the same dofile, 
unchanged, as was used to create the data being replicated.{p_end}

{phang}
{opt roundedvalues} if specified, round each final value (after inflation, if any) to the closest integer 
(Closest 0.1 if maximum value is <= 1). Default is to leave values unrounded){p_end}

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
{opth contextvars(varlist)} if specified, variables whose combinations identify different electoral contexts 
within which imputed values will be separately generated (required if the default, recorded as a 'data 
characteristic' by command {cmdab:SMcon:textvars} when the data were first {help use}d, is to be overriden).

{phang}
{opt nocontexts} if specified, override any previously specified contextvars and treat 
all observations as part of the same context .

{phang}
{opt nostacks} if specified, override any existing {it:{cmd:SMstkid}} and treat stacks as undifferentiated 
(has no effect if the {cmdab:genii:mpute} command is issued before stacking).{p_end}

{p 2}{ul:Output and naming options}{p_end}

{phang}
{opth iprefix(name)} if specified, prefix for names of imputed variables (default is to prefix each 
original {it:varname} with "ii_") when naming output variables.{p_end}

{phang}
{opth mprefix(name)} if specified, prefix for names of variables that indicate the original
missingness of each variable in {it:varlist} (default is "im_"). These generated variables are coded 
0 if the {it:varlist} variable was not missing, 1 if it was missing (and its {bf:iprefix} version has been 
assigned a non-missing value by {cmd:geniimpute}).{p_end}

{phang}
{opt keepmissing} if specified, keeps all {cmd:mprefix*} variables indicating original missingnes 
(by default these are dropped after imputed vars have been created).{p_end}

{phang}
{opt replace} if specified, drop all original varsions of newly imputed variables  
(default is to keep original as well as new variables). TAKE CARE NOT TO DROP VARIABLES NEEDED FOR A 
SUBSEQUENT IMPUTATION GOVERNED BY A SEPARATE VARLIST! Doing so will produce a "{bf:{it:variable} not found}" 
(perhaps along with an error 999) when processing that varlist.{p_end}

{p 2}{ul:Diagnostic options}{p_end}

{phang}
{opth limitdiag(#)} if specified, limits the number of contexts for which diagnostics are displayed 
to # (default is to display diagnostics, which can be quite voluminous, for all contexts).{p_end}

{phang}
{opt noadiag} equivalent to {cmd:limitdiag(0)}.{p_end}

{phang}
{opt extradiag} if specified, extend the detail of the diagnostics, when displayed.{p_end}



{title:Examples}

{phang2}{cmd:. geniimpute ptv1-ptv5 || pttaxcuts1-pttaxcuts5 || ptdefspend1-ptdefspend5 || pteduspend1-pteduspend5}
{cmd:, addvars(prox_party1-prox_party5 income uniot educ) min(0) max(10) limitdiag(5)}{p_end}

{pstd}Using unstacked data, generate plugging values to replace missing values in the above variable, having the same number 
(5) of items in each battery and the same minimum and maximum values. Battery stubnames suggest that the variables have to 
do with propensity to vote (likelihood of supporting particular political parties) support for tax cuts, support for spending 
on defence, and support for spending on education. All four requested imputations take advantage of the negative correlations 
we expect between members of the same battery and these influences are expected to be augmented through the addition of 
respondent-judged left-right proximities (presumably estimated by a previous 'gendist' procedure).{p_end}


{phang2}{cmd:. geniimpute income union educ age: turnout || turnout age: income union educ} 
{cmd:, limitdiag(5)}{p_end}

{pstd}Using stacked data, estimate plugging values to replace missing values in the above variable lists, evidently intended 
to maximize the N available for a substantive investigation into effects of four demographic variables on turnout. Conventional 
wisdom, as summarized by the help text for Stata's {help MI} suite of commands, suggests that missing data in estimation 
models should be plugged by values estimated from the same variables that the imputed data will be used to investigate. So 
turnout should play a role in estimating missing values for variables used to investigate turnout, and those same variables 
should play a role in plugging the missing data in those same indepvars. Additional variables added to the turnout model should 
also be added to the models that estimate the plugging values for independent variables. In the above example, age is treated as 
additional in both imputations since age is a variable which, in survey data, has virtually no missing observations.{p_end}



{title:Generated Variables}

{pstd}
{cmd:genyiimpute} saves the following (sets of) variables ...

{synoptset 16 tabbed}{...}
{synopt:ii_{it:name1} ii_{it:name2} ... (or other prefix set by option {bf:iprefix})} a set of variables with 
names whose suffixes match the names of original variables for which missing data has been imputed. The original 
variables are left unchanged (unless {opt rep:lace} is optioned).{p_end}

{synopt:im_{it:name1} im_{it:name2} ... (or other prefix set by option {bf:mprefix})} a set of dummy variables 
indicating, for each observation, whether the value of the new variable was imputed for that particular observation 
(i.e. whether the original observation was missing).{p_end}

{synopt:{it:SMdmisCount}} a variable showing the original count of missing items for each observation.{p_end}
{synopt:{it:SMdmisPlugCount}} a variable showing the count of remaining missing items for each observation after 
mean-plugging.{p_end}


{pstd}
Although the first two examples feature variables with numeric suffixes, suggesting that the imputed variables were 
created in  unstacked data, in practice with variables that are to be used in substantive analyses we are more likely 
to see prefixes that have substantive meaning. These substantively meaningful names may be set as {it:iprefix} options, 
but they are just as likely to derive from later renaming of default prefix-names.{p_end}

{phang}
A subsequent invocation of {cmd:geniimpute} will overwrite {it:SMimisCount} and {it:SMimisPlugCount} with 
new counts of missing values; so users should save these values under more specific names, before issuing 
the the next {cmdab:genii:mpute} command, if they will be of later interest.{p_end}
