{smcl}
{cmd:help genstats}
{hline}

{title:Title}

{p2colset 7 19 19 0}{...}
{p2col :genstats {hline 2}}Generates (optionally weighted) statistics separately for each context and stack{p_end}
{p2colreset}{...}


{title:Syntax}

{p 4 13 11}
{opt genstats varlist [if][in][weight], options}

	or

{p 4 13 11}
{opt genstats varlist [if][in][weight], options || varlist || ...}


{p 4}The second syntax permits the same options to be applied to multiple varlists.


{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{p2colset 5 26 28 2}
{synopt :{opt con:textvars(varlist)}}variables defining each context (e.g. country and year){p_end}
{synopt :{opt noc:ontexts}}disregard context distinctions{p_end}
{synopt :{opt sta:ckid(varname)}} if present, identifies different "stacks" (often battery items) across 
which statistics will be generated{p_end}
{synopt :{opt nos:tacks}}disregard distinctions between stacks/battery-items{p_end}
{synopt :{opt sta:ts(n|mean|sd|min|max|skew|kurtosis|sum|sw)}}(required) statistics 
to be generated, where {it:{opt sd}} is standard deviation and {it:{opt sw}} is sum of weights. 
Any or all keywords can be included, separated by spaces. Keywords may be abbreviated to first 3 chars.{p_end}
{synopt :{opt mnp:refix(name)}}prefix for name(s) of generated mean(s) (defaults to "mn_"){p_end}
{synopt :{opt sdp:refix(name)}}prefix for name(s) of generated standard deviation(s) (defaults 
to "sd_"){p_end}
{synopt :{opt mip:refix(name)}}prefix for name(s) of generated minimum(s) (defaults to "mi_"){p_end}
{synopt :{opt map:refix(name)}}prefix for name(s) of generated maximum(s) (defaults to "ma_"){p_end}
{synopt :{opt skp:refix(name)}}prefix for name(s) of generated skewedness (defaults to "sk_"){p_end}
{synopt :{opt kup:refix(name)}}prefix for name(s) of generated kurtosis (defaults to "ku_"){p_end}
{synopt :{opt sup:refix(name)}}prefix for name(s) of generated sum(s) (defaults to "su_"){p_end}
{synopt :{opt swp:refix(name)}}prefix for name(s) of generated sum(s) of weight(s) 
(defaults to "sw_"){p_end}
{synopt :{opt lim:itdiag(#)}}number of contexts for which to report on variables being generated 
(default is to report progress for all contexts){p_end}
{synopt :{opt nod:iag}}equivalent to {opt lim:itdiag(0)}, suppressing progress reports{p_end}

{p 4}Only the {bf:stats} option is required


{synoptline}

{title:Description}

{pstd}
The {cmd:genstats} command can be issued before or after stacking. It generates a variety of statistics 
separately for each context named in the {it:{opt contexts}} option and optionally for each stack defined by 
the {bf:{it:stackid}} option, if present. The values taken on by these statistics are duplicated onto all 
observations in each context (and stack, if optioned). {cmd:genstats} thus duplicates certain of the features 
of Stata's {help egen} command but permits unit weights to be taken into account, which {cmd:egen} does not.{break}
   Note that {cmd:genstats} can be {it:{opt call}}ed by the {help stackme} command {help genplace} in order to place 
batteries of items, in terms of statistics other than the mean, in the first step of a two-step {help genplace} 
procedure. Otherwise that first step places the battery in terms of its mean.

{pstd}
SPECIAL NOTE COMPARING {help genstats} WITH {help genplace}: The data processing performed by the first 
step of a two-step {cmd:genplace} command is computationally identical to that performed by command 
{cmd:genstats} with option {it:{opt stats(mean)}} but conceptually very different. Means are generated by 
{cmd:genstats} without regard to any conceptual grouping of variables inherent in batteries that might 
contain (some of) those variables. The command {cmd:genplace} can do the same for variables that 
are conceptually connected by being members of a battery of items but then proceeds to a second 
step in which those means (or some other placement battery defined by option {bf:cweight}) are used 
when averaging the item placements into a (weighted) mean placement regarding the battery as a whole 
(for example a legislature placed in left-right terms according to the individual placements of parties 
that are members of that legislature).{break}


{title:Options}

{phang}
{opt contextvars(varlist)} if present, variables whose combinations identify different electoral 
contexts (e.g. country and year) for each of which separate placements will be generated (same 
value for all units/respondents in each context). By default all units are assumed to belong to 
the same context.

{phang}
{opt nocontexts} if present, disregard distinctions between contexts (equivalent to using {help egen} with 
no {bf{it{by}} option, unless {bf{it{stackid}} is used.

{phang}
{opt stackid(varname)} a variable identifying each different "stack" (equivalent to 
the {it:j} index in Stata's {bf:{help reshape:reshape long}} command) for which statistics will be 
separately generated. The default is to use the "SMstkid" variable, if present. 

{phang}
{opt nostacks} if present, disregard distinctions between stacls.

{phang}
{opt stats(n|mean|sd|min|max|skew|kurtosis|sum|sw)} (required) statistic(s) to be generated, 
where {it:sd} is standard deviation and {it:sw} is sum of weights. Any or all keywords can be included, 
separated by spaces, and may be abbreviated to their first 3 chars. Execution is slowed if skew, kurtosis, 
median and/or mode are requested{p_end}

{phang}
{opt mnp:refix(name)}prefix for name(s) of generated mean(s) (defaults to "mn_"){p_end}

{phang}
{opth sdp:refix(name)}prefix for name(s) of generated standard deviation(s) (defaults 
to "sd_"){p_end}

{phang}
{opt mip:refix(name)}prefix for name(s) of generated minimum(s) (defaults to "mi_"){p_end}

{phang}
{opt map:refix(name)}}prefix for name(s) of generated maximum(s) (defaults to "ma_"){p_end}

{phang}
{opt skp:refix(name)}prefix for name(s) of generated skewedness (defaults to "sk_"){p_end}

{phang}
{opt kup:refix(name)}prefix for name(s) of generated kurtosis (defaults to "ku_"){p_end}

{phang}
{opt sup:refix(name)}prefix for name(s) of generated sum(s) (defaults to "su_"){p_end}

{phang}
{opt swp:refix(name)}prefix for name(s) of generated sum(s) of weight(s) (defaults to "sw_"){p_end}

{phang}
{opt limitdiag(#)} only display diagnostic reports for the first # contexts (by default report 
variables created for all contexts).{p_end}

{phang}
{opt nodiag} equivalent to {opth limitdiag(0)}.{p_end}

{p 4}Only the {bf:stats} option is required.


{title:Examples:}

{pstd}The following command, issued after stacking, generates a set of "mn_" prefixed wt-weighted means, 
constant across respondents within contexts (and stacks if the data are stacked) for the variable measuring 
respondents' left-right positions.{p_end}

{phang2}{cmd:. genstats rlr [aw=wt], stat(mean) context(cid year) stackid(stkid)} {p_end}{break}


{title:Generated variables}

{pstd}
{cmd:genstats} saves the following variables or sets of variables:

{synoptset 18 tabbed}{...}
{synopt:mn_{it:var} mn_{it:var} ...} (or other prefix set by option {bf:mnprefix}) (perhaps 
weighted) means, constant over contexts and/or stacks, for each variable in {it:varlist}.{p_end}

{synopt:sd_{it:var} sd_{it:var} ...} (or other prefix set by option {opt sdprefix}) (perhaps weighted) 
standard deviations, constant over contexts and/or stacks, for each variable in {it:varlist}.{p_end}

{synopt:mi_{it:var} mi_{it:var} ...} (or other prefix set by option {opt miprefix}) (perhaps weighted) 
minimums, constants over context and/or stacks, for each variable in {it:varlist}.{p_end}

{pstd}Such other variables as may be created to hold other optioned statistics (see option {opt stats} 
and associated prefix options).{p_end}

