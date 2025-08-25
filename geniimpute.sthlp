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
{opt genii:mpute} {bf:{varlist}} {ifin}{weight} {bf:, options}

{p 8}
or

{p 8 16 2}
{opt genii:mpute} {it:[addvars:]}{varlist} {ifin}{weight} [ || {it:[addvars:]}{varlist} {weight} [ ...
				  {it:[addvars:]}{varlist} {weight} {bf:, options} ] ]

	
{p 4 4 2}Though illustrated with especially appropriate examples, the two syntax formats are interchangeable. 
Each can be used with either stacked or unstacked data. {bf:Speed of execution} can be much increased by grouping 
together varlists that employ the same options, as illustrated by the second syntax example. That format also 
permits a list of additional variables (see option {opt add:vars}) to be named as a prefix to each varlist. See 
{bf:Description}, below, for details.

{p 4 4 2}If the second syntax is being employed 'if/in' expressions should suffix the first varlist and ', options...' 
should suffix the final {varlist}; weights can follow any or all {varlist}s.

{p 4 4 2}Names for imputed versions of {varlist} are constructed by prefixing with "ii_" (or with "i" followed by 
some other prefix set by option {opt ipr:efix}) the name of the variable for which missing values are imputed.

{p 4 4 2}aweights, fweights, iweights, and pweights are allowed; see {help weight}.


{synoptset 19 tabbed}{...}
{synopthdr}
{synoptline}

{p 2}{ul:Imputation options}

{p2colset 4 21 23 2}{synopt :{opt add:vars(varlist)}}additional variables to include in the imputation model (can 
alternatively preceed the initial colon of a syntax 2 varlist){p_end}
{synopt :{opt sel:ected}}selects variables from the {opt additional} list only if they have no more 
missing values than the {bf:{varlist}} variable with most missing data{p_end}
{synopt :{opt noi:nflate}}do not inflate the variance of imputed values to match the variance of original 
item values (default is to add random perturbations to these values, as required){p_end}
{synopt :{opt rou:ndedvalues}}round each imputed value, after inflation, to the nearest integer (default 
is to leave imputed values unrounded){p_end}
{synopt :{opt bou:ndedvalues}}bound the range of imputed values for each {it:varlist} variable to the same 
bounds as found for that variable's unimputed values{p_end}
{synopt :{opt rangeofvalues(min#,max#)}}minimum and maximum values to which imputed values will be constrained 
(equivalent to the two legacy options {opt min:ofrange} and {opt max:ofrange}) that serve as otherwise 
undocumented alternatives{p_end}
{synopt :{opt fas:t}}suppress the collection of statistics used for diagnostic output.{p_end}

{p 2}{ul:Data-structure options}

{synopt :{opt con:textvars(varlist)}}(generally unspecified) a set of variables identifying the different electoral 
contexts within missing values will be separately imputed (required if the default contextnames, recorded as a 'data 
characteristic' by command {help stackme##SMcontextnames:{ul:SMcon}textnames}, is to be overriden){p_end}
{synopt :{opt nocon:texts}}override the default behavior that generates distances within each context separately.{p_end}
{synopt :{opt nosta:cks}}override the default behavior that treats each stack as a separate context (has 
no effect if data are not stacked){p_end}

{syntab:{ul:Output and naming options}}

{synopt :{opt ipr:efix(name)}}replacement for 2nd char of prefix for generated imputed variables (default is "ii_"){p_end}
{synopt :{opt mpr:efix(name)}}replacement for 2nd char of prefix for generated variables indicating original missingness
of a variable (default is "im_"){p_end}
{synopt :{opt kee:pmissing}}keeps all generated variables indicating original missingness, even if {opt rep:lace (see 
below) is optioned{p_end}
{synopt :{opt rep:lace}}drops all original variables in {it:{it:varlist}} after imputation, along with missing value 
indicators unless {kee:pmissing} (see above) was optioned{p_end}

{syntab:{ul:Diagnostics options}}

{synopt :{opt lim:itdiag(#)}}number of contexts for which to display diagnostics as imputation progresses 
(default is to display diagnostics for all contexts){p_end}
{synopt :{opt nod:iag}}equivalent to {opt lim:itdiag}(0){p_end}
{synopt :{opt ext:radiag}}extend any displayed diagnostics with extra detail{p_end}

{synoptline}
{marker Description}
{title:Description}

{pstd}
The command name "geniimpute" (abbreviation 'genii') has two 'i's that stand for "inflated imputed" because 
imputed values of variables that were missing before imputation have, by default, their variance randomly 
inflated to match the variance of the non-missing values of the same variable, thus emulating the data 
expected by Stata's {help mi} suite of commands. Though {cmd:geniimpute} can impute (optionally 
variance-inflated) missing values for a single variable (by calling Stata's obsolete but still available 
{cmd:impute} command and augmenting the output from that command according to various options described 
below) its primary function is to impute multiple variables contained in a {help stackme_battery} (generally  
the items that constitute separate answers to a single survey question). Imputation follows an incremental 
procedure which - by default - is applied separately to each electoral context identified by 
{cmd:stackMe}'s {help stackme##SMcontextvars}, as follows:

{p 6 6 2}1) Within each context, observations are split into groups based on the number of missing items.
Observations for which only one variable has a missing value are processed first, and so on.

{p 6 6 2}2) Within each of the above groups, variables are ranked according to the number of missing 
observations. Variables with fewer missing observations are processed first, and so on.

{p 6 6 2}3) According to the order defined in step 2 (and within each group defined in step 1), variables 
are imputed through an augmented simple imputation, based on Stata's (superceded) {cmd:impute} command.

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
context and not only a restricted group of observations defined in step 1.

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
produced by Stata's {help mi}) in the size of an (often) already very large dataset.

{pstd} NOTE that, if the data need to be replicable, each dataset to be used in 
multiple imputation will need to be produced by a separate invocation of {cmd:geniimpute} that would follow 
a Stata {help set seed} command; and those seeds would need to be recorded in Stata's data {help note}s or 
elsewhere.



{title:Options} 

{p 2}{ul:Imputation options}{p_end}

{phang}
{opth add:vars(varlist)} if specified, additional variables to include in the imputation model 
beyond those in {it:varlist}. These additional variables will not have any missing values imputed. 
In syntax 2 these variables can be specified before the colon that introduces the variables for 
which missing values are to be imputed.

{phang}
{opt sel:ected} if specified, selects among {it:additional} variables only those with no more 
missing values than the {it:varlist} variable with the largest number of missing values.{p_end}

{phang}
{opt rou:ndedvalues} if specified, round each final value (after inflation, if any) to the closest integer 
(Closest 0.1 if maximum value is <= 1). Default is to leave values unrounded.{p_end}

{phang}
{opt boundedvalues} if specified, bounds the minimum and maximum of imputed values to the  
min/max found in unimputed values of the same variable. This overrides minofrange/maxofrange 
for specific variables if the bounded range is smaller. Seldom used with variable batteries.{p_end}

{phang}
{opth ran:geofvalues(min#,max#)} if specified, minimum and maximum value of the item range used for constraining 
imputed value(s). {bf:Note} that this option constrains the value(s) used for imputing all variables in {varlist} 
to the same minimum and maximum (useful when imputing missing values for batteries of variables that should all have 
the same range). Although not otherwise documented, the legacy options {opt min:ofrange} and {opt max:ofrange} 
are still recognized as alternatives.{p_end}

{phang}
{opt fast} if specified, suppresses the collection of statistics displayed as diagnostics (so also suppresses 
diagnostic output even if {opt nod:iag} was not optioned). The time-saving can be imperceptible with aggregate 
or single-survey data.{p_end}

{p 2}{ul:Data-structure options}{p_end}

{phang}
{opt con:textvars(varlist)} (generally unspecified) a (set of) variable(s) identifying the different contexts 
within which missing data will be separately imputed. By default, context varnames are taken from a Stata .dta 
file {help char:characteristic} established by {cmd:stackMe}'s command {help stackme##SMcontextvars:{ul:SMcon}textvars} 
(which can also establish that the file has no contexts to be distinguished) the first time this file was opened 
for {help use} by a {cmd:stackMe} command. So this option is required if the default is to be overriden.

{phang}
{opt nocon:texts} if present, overrides the default behavior of imputing missing values within each context 
separately.

{phang}
{opt nosta:cks} if present, overrides the default behavior of treating each stack as a separate context (has 
no effect if data are not stacked).

{p 2}{ul:Output and naming options}{p_end}

{phang}
{opth iprefix(name)} if specified, replacement for second character of prefix for names of imputed variables 
(default is to prefix each original {it:varname} with "ii_" or "i" followed by some other prefix establisned 
by option {opt ipr:efix}) when naming output variables generated by {cmdab:genii:mpute}.{p_end}

{phang}
{opth mprefix(name)} if specified, replacement for second character  of prefix for names of variables that 
indicate the original missingness of each variable in {it:varlist} (either "im_" or the letter "i" followed 
by some other prefix set by option {opt mpr:efix}). These generated variables are coded 0 if the {it:varlist} 
variable was not missing or 1 if it was missing (and its {bf:iprefix} version has been plugged with an imputed 
value by {cmd:geniimpute}).{p_end}

{phang}
{opt keepmissing} if specified, keeps all {cmd:mprefix*} variables indicating original missingnes, even if 
{cmd rep:lace} (see below) is optioned.{p_end}

{phang}
{opt replace} if specified, drops all original variables for which imputed versions have been created, along 
with missing indicators for those variables (unless {opt kee:pmissing} was optioned). Default is to keep 
original as well as new variables. TAKE CARE NOT TO DROP VARIABLES NEEDED FOR A SUBSEQUENT IMPUTATION GOVERNED 
BY A SEPARATE VARLIST! Doing so will produce a "{bf:{it:variable} not found}" (perhaps along with an error 999) 
when processing that varlist.{p_end}

{p 2}{ul:Diagnostic options}{p_end}

{phang}
{opth limitdiag(#)} if specified, limits the number of contexts for which diagnostics are displayed 
to # (default is to display diagnostics, which can be quite voluminous, for all contexts).{p_end}

{phang}
{opt noadiag} equivalent to {cmd:limitdiag(0)}.{p_end}

{phang}
{opt extradiag} if specified, extends the detail of the diagnostics, when displayed.{p_end}



{title:Examples}

{phang2}{cmd:. geniimpute ptv1-ptv5 || ptclose1-ptclose5 || taxcuts1-taxcuts5 || eduspend1-eduspend5}
{cmd:, addvars(lrparty1-lrparty5) range(0,10) round contextvars(cntryid year) limitdiag(5)}{p_end}

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
{synopt:ii_{it:name1} ii_{it:name2} ... (or other prefix set by option {bf:iprefix})} a set of variables with 
names whose suffixes match the names of original variables for which missing data has been imputed. The original 
variables are left unchanged (unless replaced).{p_end}

{synopt:im_{it:name1} im_{it:name2} ... (or other prefix set by option {bf:mprefix})} a set of dummy variables 
indicating, for each observation, whether the value of the new variable was imputed for that particular observation 
(i.e. whether the original observation was missing).{p_end}

{synopt:SMimisCount} a variable showing the original count of missing items for each observation.{p_end}
{synopt:SMimisImpCount} a variable showing the count of remaining missing items for each observation after 
plugging those with imputed values.{p_end}


{pstd}
Although both examples feature variables with numeric suffixes, suggesting that the imputed variables were created in  
unstacked data, in practice with variables that are to be used in substantive analyses we are more likely to see 
prefixes that have substantive meaning. These substantively meaningful names may be set as {it:iprefix} options, 
but they are just as likely to derive from later renaming of default prefix-names, bearing in mind that defining new 
prefixes calls for a new {cmdab:genii:mpute} command.{p_end}
