{smcl}
{cmd:help geniimpute}
{hline}

{title:Title}

{p2colset 5 19 19 2}{...}
{p2col :{bf:geniimpute} {hline 2}}Incremental simple (or multiple separate) imputation(s) of a set of variables 
(read StackMe's {help stackme##Genericvariable:Generic variables} help-text before proceeding){p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{opt genii:mpute [if][in][weight]} {it:stacked}_{varlist}{cmd:,} {opt options}

{p 4 4 2}
or

{p 8 16 2}
{opt genii:mpute [if][in][weight]} {it:unstacked}_[addvars:]{varlist}{cmd:,} {opt options} [ {cmd:||} {it:unstacked}_[addvars:]{varlist}  ... ]


{p 4 4 2}
where a stacked {varlist} consists of {varname}s constructed from the stubs of unstacked {varname}s when 
those were {help reshape}d by the {help StackMe} command {help genstacks}. Syntax 2 permits a list of 
additional variables (see option {opt add:vars}), followed by a colon, to optionally preceed the (required) 
{varlist}.  See {bf:Description}, below, for details.
	
{p 4 4 2}Though illustrated with especially appropriate examples, the two syntax formats are interchangeable. 
Each can be used with either stacked or unstacked data. {bf:Speed of execution} can be much increased by grouping 
together varlists that employ the same options.

{p 4 4 2}Names for imputed versions of {varlist} are constructed by prefixing (by "i_" or another prefix set 
by option {opt ipr:efix}) the name of the variable for which missing values are imputed.


{synoptset 19 tabbed}{...}
{synopthdr}
{synoptline}

{p 2}{ul:Imputation options}

{p2colset 4 21 22 2}{synopt :{opt add:vars(varlist)}}additional variables to include in the imputation model (can 
alternatively preceed the initial colon of a syntax 2 varlist){p_end}
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

{synopt :{opt con:textvars(varlist)}}a set of variables identifying different electoral contexts 
(by default all cases are treated as part of the same context){p_end}
{synopt :{opt nocon:texts}}delete any previously-defined context variables{p_end}
{synopt :{opt sta:ckid(varname)}}a variable identifying different "stacks" for which values will be 
separately imputed if {cmd:geniimpute} is issued after stacking{p_end}
{synopt :{opt nos:tacks}}override the default behavior that treats each stack as a separate context{p_end}

{syntab:{ul:Output and naming options}}

{synopt :{opt ipr:efix(name)}}prefix for generated imputed variables (default is "i_"){p_end}
{synopt :{opt mpr:efix(name)}}prefix for generated variables indicating original missingness
of a variable (default is "m_"){p_end}
{synopt :{opt kee:pmissing}}keeps all generated variables indicating original missingness (otherwise dropped){p_end}
{synopt :{opt rep:lace}}drops all original variables in {it:{it:varlist}} after imputation{p_end}

{syntab:{ul:Diagnostics options}}

{synopt :{opt lim:itdiag(#)}}number of contexts for which to display diagnostics (these can 
be quite voluminous) as imputation progresses (default is to display diagnostics for all contexts){p_end}
{synopt :{opt nod:iag}}equivalent to {opt lim:itdiag}(0){p_end}
{synopt :{opt ext:radiag}}extend any displayed diagnostics with extra detail{p_end}

{synoptline}

{title:Description}

{pstd}
The command name "geniimpute" (abbreviation 'genii') has two 'i's that stand for "inflated imputed" because 
imputed values of variables that were missing before imputation have, by default, their variance randomly 
inflated to match the variance of the non-missing values of the same variable, thus emulating the data 
expected by Stata's {help mi} suite of commands. Though {cmd:geniimpute} can impute (optionally 
variance- inflated) missing values for a single variable (by calling Stata's obsolete but still available 
{cmd:impute} command and augmenting the output from that command according to various options described 
below) its primary function is to impute multiple variables contained in a {help stackme_battery} (generally  
the items that constitute separate answers to a single survey question). Imputation follows an incremental 
procedure which - if required - is applied separately to each electoral context identified by 
{opt contextvars}, as follows:

{p 6 6 2}1) Within each context, observations are split into groups based on the number of missing items.
Observations for which only one variable has a missing value are processed first, and so on.

{p 6 6 2}2) Within each of the above groups, variables are ranked according to the number of missing 
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
NOTE (1) that the sample used in the imputation model is the whole electoral 
context and not only a restricted group of cases defined in step 1.

{pstd}
NOTE (2) that the number of independent variables upon which to base the imputation (the total of 
{varlist} and {cmd:additional}) is limited to 30 because that is the limit for Stata's {cmd:impute} 
command. This limitation might lead the user to prefer to issue the {cmd:geniimpute} command after 
{help genstacks} and {help genyhats} have reduced the number of indeps in the dataset.

{p 6 6 2}4) The output of Stata's {cmd:impute} command is then optionally augmented by inflating the variance 
of imputed item values to match the variance of original item values, as recommended in the literature. 
If this is not wanted then the option {cmd:noinflate} should be employed.

{p 6 6 2}5) Imputed values should, in principle. approximate the values observed in the data, but are seldom 
the same as those values. Discrete intervals can be enforced if data are {cmd:rounded}. Predicted values 
beyond the rage observed in the data might survive such rounding but can be eliminated by using the {cmd:minofrange()} 
and/or {cmd:maxofrange()} options to constrain imputed values. Applying such constraints can be useful when a 
battery of analogous items is being imputed. This might suggest specifying multiple variable lists (separated 
by "||"), each accompanied by different options (but speed of execution can be much increased if options are 
left unchanged for multiple varlists, with minimum and maximum constraints being applied separately using 
Stata's {help replace} {help if}...). When imputing a set of heterogeneous variables (not members of a single 
battery) imputed values of each separate variable can be {cmd:bounded} by the minimum and maximum observed 
for that member of the heterogenious set (thus producing imputations whose bounds vary appropriately even 
without new options being applied). By default no constraints are applied.

{pstd}
The {cmd:geniimpute} command can be issued before or after stacking. If issued after stacking, by default it 
treats each stack as a separate context to take into account along with any higher-level contexts. However, 
the {cmd:nostack} option can be employed to force {cmd:geniimpute} to ignore stack-specific contexts. In 
addition, the {cmd:geniimpute} command can be employed with or without distinguishing between higher-level 
contexts, if any, (with or without the {cmd:contextvars} option or omitting certain variable(s) from that 
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
produced by Stata's {help mi}) in the size of an already very large dataset.

{pstd} NOTE that, if the data need to be replicable, each dataset to be used in 
multiple imputation will need to be produced by a separate invocation of {cmd:geniimpute} that would follow 
a Stata {help set seed} command; and those seeds would need to be recorded in Stata's data {help note}s or 
elsewhere.



{title:Options} {sf:(none of these are required)}

{p 2}{ul:Imputation options}{p_end}

{phang}
{opth addvars(varlist)} if specified, additional variables to include in the imputation model 
beyond those in {it:varlist}. These additional variables will not have any missing values imputed. 
In syntax 2 these variables can be specified before the colon that introduces the variables for 
which missing values are to be imputed.

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
{opt nocontexts} if specified, override any previously specified contextvars and treat 
all cases as part of the same context 

{phang}
{opth stackid(varname)} if specified, a variable identifying different "stacks" for which values will be 
separately imputed in the absence of the {cmd:nostack} option. The default is to use the "stackMe_stackid" 
variable if the {cmd:geniimpute} command is issued after stacking.

{phang}
{opt nostacks} if specified, override any previoulsy specified stackid and treat stacks as undifferentiated 
(has no effect if the {cmd:genyhats} command is issued before stacking).{p_end}

{p 2}{ul:Output and naming options}{p_end}

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



{title:Examples}

{phang2}{cmd:. geniimpute ptv1-ptv5 || ptclose1-ptclose5 || taxcuts1-taxcuts5 || eduspend1-eduspend5}
{cmd:, addvars(lrparty1-lrparty5) minofrange(0) maxofrange(10) round contextvars(cntryid year) limitdiag(5)}{p_end}

{pstd}Generate iimputed versions of four batteries of unstacked variables having the same number (5) of items in each 
battery and the same minimum and maximum values. Battery stubnames suggest that the variables have to do with political 
parties. All four requested imputations get a boost from the addition of respondent-judged left-right positions of 
the same five parties – positions that have no missing data because they are averaged across the respondents who 
have an opinion about where parties stand (see the help text for {help gendist}). Imputations are to be performed 
separately for each country and year and diagnostics are to be displayed for the first five of the contexts involved. 
Had there been any more batteries of variables based on questions asked regarding the same five parties, those should 
ideally have figured in additional variable lists, unless their maxema and/or minema were different (but uniform 
maximums and minimums could also be applied in one or more later {help replace} commands). Performing these
imputations on unstacked data means that respondent ratings of other parties get to inform the imputation of ratings 
that are missing for particular parties.{p_end}


{phang2}{cmd:. geniimpute turnout: income union educ || vote: income union educ, contextvars(cntryid year)} 
{cmd:stackid(stackme_stkid) limitdiag(5)}{p_end}

{pstd}Using stacked data, the two missing data imputations called for by the above variable lists are evidently 
intended to maximize the N available for a substantive investigation into effects of the same social class 
variables on, first, turnout and, second, party choice. Conventional wisdom, as summarized by the help text for 
Stata's {help MI} suite of commands, seems to be that missing data in estimation models should be plugged by 
values estimated from the same variables that the imputed data will be investigating. So turnout should play a 
role in estimating missing values in the variables used to investigate turnout and vote choice should replace 
turnout when the research focus switches from turnout to voting choice.{p_end}



{title:Generated Variables}

{pstd}
{cmd:genyiimpute} saves the following (sets of) variables ...

{synoptset 16 tabbed}{...}
{synopt:i_{it:name1} i_{it:name2} ... (or other prefix set by option {bf:iprefix})} a set of variables with 
names whose suffixes match the names of original variables for which missing data has been imputed. The original 
variables are left unchanged (unless replaced).{p_end}

{synopt:m_{it:name1} m_{it:name2} ... (or other prefix set by option {bf:mprefix})} a set of dummy variables 
indicating, for each case, whether the value of the new variable was imputed for that particular observation 
(i.e. whether the original observation was missing).{p_end}

{pstd}
Although both examples feature variables with numeric suffixes, suggesting that the imputed variables were created in  
unstacked data, in practice with variables that are to be used in substantive analyses we are more likely to see 
prefixes that have substantive meaning. These substantively meaningful names may be set as {it:iprefix} options, 
but they are just as likely to derive from later renaming of default prefix-names, bearing in mind that defining new 
prefixes in the course of a command-line can slow down (if only marginally) the execution of that command.{p_end}

{pstd}
NOTE: The user can add counts of missing/nonmissing values for any set of variables (whose missing values have or have 
not been replaced with imputed values) by using STATA's {help rowmiss} and {help rownonmiss} functions within its egen 
command.{p_end}
