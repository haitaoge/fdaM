smooth.GLM <- function(argvals, y, fdParobj, weight, fdnames, covariates, 
                       dfscale, family, control, start) {

#SMOOTH.GLM  Smooths discrete curve represented by basis function
#  expansions fit by penalized least squares.
#
#  Required arguments for this function are
#
#  ARGVALS  ... A set of argument values, set by default to equally spaced
#               on the unit interval (0,1).
#  Y        ... an array containing values of curves
#               If the array is a matrix, rows must correspond to argument
#               values and columns to replications, and it will be assumed
#               that there is only one variable per observation.
#               If Y is a three-dimensional array, the first dimension
#               corresponds to argument values, the second to replications,
#               and the third to variables within replications.
#               If Y is a vector, only one replicate and variable are
#               assumed.
#               In the binomial case with local sample sizes M.i,
#               Y is a cell array of length 2, the first of which cantains
#               the matrix or array above containing observed frequencies,
#               and the second of which contains the corresponding local
#               sample sizes.
#  FDPAROBJ ... A functional parameter or fdPar object.  This object
#               contains the specifications for the functional data
#               object to be estimated by smoothing the data.  See
#               comment lines in function fdPar for details.
#               This argument may also be either a FD object, or a
#               BASIS object.  If this argument is a basis object, the
#               smoothing parameter LAMBDA is set to 0.
#
#  Optional arguments are input in pairs  the first element of the pair
#     is a string specifying the property that the argument value defines,
#     and the second element is the value of the argument
#
#     Valid property/value pairs include
#
#     Property        Value
#     ----------------------------------------------------------------
#     weight          vector of the same length as the data vector to be
#                     smoothed, containing nonnegative weights to be
#                     applied to the data values
#     fdnames         A cell array of length 3 with names for
#                       1. argument domain, such as 'Time'
#                       2. replications or cases
#                       3. the function.
#     covariates      A N by Q matrix Z of covariate values used to augment
#                     the smoothing function, where N is the number of
#                     data values to be smoothed and Q is the number of
#                     covariates.  The process of augmenting a smoothing
#                     function in this way is often called "semi-parametric
#                     regression".  The default is the empty object [].
#     dfscale         A scalar value multiplying the degrees of freedom
#                     in the definition of the generalized
#                     cross-validated or GCV criterion for selecting the
#                     bandwidth parameter LAMBDA.  It was recommended by
#                     Chong Gu that this be a number slightly larger than
#                     1.0, such as 1.2, to prevent under-smoothing,
#                     The default is 1.0.
#     family          a character string containing one of
#                       'normal'
#                       'binomial'
#                       'poisson'
#                       'gamma'
#                       'inverse gaussian'
#                     the value determines which of the link functions in
#                     the generalized linear model (GLM) family is to be
#                     used.  The default is 'normal'.
#      control        a struct object controlling iterations with members
#                       epsilon  convergence criterion (default 1e-8)
#                       maxit    max. iterations       (default 25)
#                       trace    output iteration info (0)
#      start          a vector containing starting values for coefficients
#
#
#  Returned objects are
#
#  FDOBJ   ... an object of class fd containing coefficients.
#  DF      ... a degrees of freedom measure.
#  GCV     ... a measure of lack of fit discounted for df.
#                 If the function is univariate, GCV is a vector
#                 containing the error  sum of squares for each
#                 function, and if the function is multivariate,
#                 GCV is a NVAR by NCURVES matrix.
#  SSE     ... the error sums of squares.
#                 SSE is a vector or matrix of the same size as
#                 GCV.
#  PENMAT  ... the penalty matrix, if computed, otherwise [].
#  Y2CMAP  ... the matrix mapping the data to the coefficients.
#  ARGVALS ... the input set of argument values.
#  Y       ... the input array containing values of curves

#  Last modified 16 September 2014 by Jim Ramsay

#  check ARGVALS

[argvals, n] = argcheck(argvals)

#  check Y

[y, ncurve, nvar, ndim] = ycheck(y, n)

#  check FDPAROBJ and get FDOBJ and LAMBDA

fdParobj = fdParcheck(fdParobj)
# fdobj    = getfd(fdParobj)
# lambda   = getlambda(fdParobj)
# Lfdobj   = getLfd(fdParobj)

fdobj   = fdParobj$fd
lambda  = fdParobj$lambda
Lfdobj  = fdParobj$Lfd

#  check LAMBDA

if (lambda < 0){lambda = 0}

#  get BASIS and NBASIS

# basisobj = getbasis(fdobj)
# nbasis   = getnbasis(basisobj) - length(getdropind(basisobj))

basisobj  = fdobj$basis
nbasis = basisobj$nbasis - length(basisobj$dropind)


#  set default argument values

deffdnames = list('arguments','replications','variables')

# deffdnames = cell(1,3)
# deffdnames{1} = 'arguments'
# deffdnames{2} = 'replications'
# deffdnames{3} = 'variables'

#  set up the argument names and argument default values

# paramNames = {     'weight' 'fdnames' 'covariates' 'dfscale' 'family'}
# paramDflts = {[]     deffdnames      []        1.0     'normal'}

wtvec      = NULL
fdnames    = deffdnames
covariates = NULL
dfscale    = 1
family     = 'binomial'

# wtvec      = []
# fdnames    = deffdnames
# covariates = []
# dfscale    = 1
# family     = 'binomial'

# Which style of calling sequence is being used
#    name -- value pairs or fixed order?

NameValStyle = true
if ~isempty(varargin) && nargin <= 7
   va1 = varargin{1}
   if ~ischar(va1) || isempty(va1)
      NameValStyle = false
   end
end

if (is.null())

if NameValStyle

    # Process optional number of name -- value pairs.

    nargpr = nargin - 3
    if floor(nargpr/2)*2 ~= nargpr
        error(['The number of argments after the first three ', ...
            'is not an even number.'])
    end

    for ipr=52nargin
        ArgName = varargin{ipr-4}
        if     strcmp(ArgName, 'w')         || ...
               strcmp(ArgName, 'wt')        || ...
               strcmp(ArgName, 'wgt')       || ...
               strcmp(ArgName, 'weight')    || ...
               strcmp(ArgName, 'weights')
            wtvec      = varargin{ipr-3}
        elseif strcmp(ArgName, 'f')         || ...
               strcmp(ArgName, 'fdname')    || ...
               strcmp(ArgName, 'fdnames')
            fdnames    = varargin{ipr-3}
        elseif strcmp(ArgName, 'c')         || ...
               strcmp(ArgName, 'cov')       || ...
               strcmp(ArgName, 'covariate') || ...
               strcmp(ArgName, 'covariates')
            covariates = varargin{ipr-3}
        elseif strcmp(ArgName, 'f')         || ...
               strcmp(ArgName, 'fam')       || ...
               strcmp(ArgName, 'family')
            family = varargin{ipr-3}
        elseif strcmp(ArgName, 'd')         || ...
               strcmp(ArgName, 'df')        || ...
               strcmp(ArgName, 'dfscl')     || ...
               strcmp(ArgName, 'dfscale')
            dfscale    = varargin{ipr-3}
        elseif strcmp(ArgName, 'con')       || ...
               strcmp(ArgName, 'control')
            control    = varargin{ipr-3}
        elseif strcmp(ArgName, 's')         || ...
               strcmp(ArgName, 'st')        || ...
               strcmp(ArgName, 'start')
            start    = varargin{ipr-3}
        else
            error('An argument name is unrecognizable.')
        end
    end
else

    #  process argument values in fixed order

    if nargin >= 4,  wtvec      = varargin{1}   end
    if nargin >= 5,  fdnames    = varargin{2}   end
    if nargin >= 6,  covariates = varargin{3}   end
    if nargin >= 7,  family     = varargin{4}   end
    if nargin == 8,  dfscale    = varargin{5}   end
    if nargin > 7
        error('More than seven non-named arguments found.')
    end
end

#  check WTVEC

[wtvec, onewt] = wtcheck(n, wtvec)
if onewt
    wtvec = ones(n,1)
end

#  check FDNAMES

if ~iscell(fdnames)
    error('smooth.basis.LSfdnames', ...
          'Optional argument FDNAMES is not a cell array.')
end

if length(fdnames) ~= 3
    error('smooth.basis.LSfdnames', ...
          'Optional argument FDNAMES is not of length 3.')
end

#  check COVARIATES

q = 0
if ~isempty(covariates)
    if ~isnumeric(covariates)
        error('smooth.basis.LScovariates', ...
            'Optional argument COVARIATES is not numeric.')
    end
    if size(covariates,1) ~= n
        error('smooth.basis.LScovariates', ...
            'Optional argument COVARIATES has incorrect number of rows.')
    end
    q = size(covariates,2)
end

#  ------------------------------------------------------------------
#                set up the linear equations for smoothing
#  ------------------------------------------------------------------

#  set up matrix of basis function values

basismat  = eval.basis(argvals, basisobj)

if n >= nbasis || lambda > 0

    #  The following code is for the coefficients completely determined

    #  set up additional rows of the least squares problem for the
    #  penalty term.

    basismat0 = basismat
    y0        = y

    if lambda > 0
#         nderiv  = getnderiv(Lfdobj)
        penmat  = eval.penalty(basisobj, Lfdobj)
        lamRmat = lambda.*penmat
#         [V,D] = eig(full(penmat))
#         Dvec  = diag(D)
#         [Dsort, Isort] = sort(Dvec, 'descend')
#         Vsort = V(,Isort)
        #  Check that the lowest eigenvalue in the series that is to be
        #  kept is positive.
#         eiglow = nbasis - nderiv
#         if Dsort(eiglow) <= 0
#             error('smooth.basiseig', ...
#                   ['Eigenvalue(NBASIS-NDERIV) of penalty matrix ', ...
#                    'is not positive check penalty matrix.'])
#         end
#         #  Check that the highest eigenvalue that is not used is small
#         #  relative to the largest eigenvalue.
#         if nderiv > 0 && log10(Dsort(eiglow+1)/Dsort(1)) > -1e-12
#             error('smooth.basiseig', ...
#                   ['Eigenvalue(NBASIS-NDERIV+1) of penalty matrix ', ...
#                    'is not small relative to eigenvalue(1) ', ...
#                    'check penalty matrix.'])
#         end
        #  Compute the square root of the penalty matrix in the subspace
        #  spanned by the first N - NDERIV eigenvectors
#         ind = 1eiglow
#         penfac = Vsort(,ind)*diag(sqrt(Dsort(ind)))
#         #  Augment basismat by sqrt(lambda).*penfac'
#         basismat = [basismat sqrt(lambda).*penfac']
#         #  Augment data vector by n - nderiv 0's
#         if ndim < 3
#             y = [y zeros(nbasis-nderiv,ncurve)]
#         else
#             for ivar=1nvar
#                 y(,,ivar) = [y(,,ivar) zeros(n-nderiv,ncurve)]
#             end
#         end
    else
        lamRmat = []
    end

    #  augment BASISMAT0 and BASISMAT by the covariate matrix
    #  if it is supplied

    if ~isempty(covariates)
        sparsewrd = issparse(basismat0)
        basismat0 = full([basismat0, covariates])
        basismat  = full([basismat,  covariates])
        if sparsewrd
            basismat0 = sparse(basismat0)
            basismat  = sparse(basismat)
        end
        if ~isempty(lamRmat)
            lamRmat = [[lamRmat,         zeros(nbasis,q)]
                       [zeros(q,nbasis), zeros(q)       ]]
        end
    end

    #  ------------------------------------------------------------------
    #               compute solution using Matlab function glmfit
    #  ------------------------------------------------------------------

    if ndim < 3
        coef  = zeros(nbasis,ncurve)
        dev   = zeros(ncurve,1)
        [coef,dev] = glm.fda(basismat, y, family, lamRmat, wtvec)
    else
        coef  = zeros(nbasis,ncurve,nvar)
        dev   = zeros(ncurve,nvar)
        for ivar=1nvar
            yi = squeeze(y(,,ivar))
            [coefi,devi] = glm.fda(basismat, yi, family, lamRmat, wtvec)
            coef(,,ivar) = coefi
            dev(,ivar)    = devi
            stats{,ivar}  = statsi
        end
    end

    #  compute basismat*R^{-1}

    if isempty(lamRmat)
        M = basismat'*basismat
    else
        M = basismat'*basismat + lamRmat
    end

    #  compute map from y to c

    y2cMap = M\basismat'

    #  compute degrees of freedom of smooth

    df = sum(diag(basismat*y2cMap))

else
    error(['The number of basis functions exceeds the number of ', ...
           'points to be smoothed.'])
end

#  ------------------------------------------------------------------
#            compute SSE, yhat, GCV and other fit summaries
#  ------------------------------------------------------------------

#  compute error sum of squares

if ndim < 3
    yhat = basismat0 * coef
    SSE  = sum((y0 - yhat).^2)
else
    SSE = zeros(nvar,ncurve)
    for ivar = 1nvar
        coefi = squeeze(coef(,,ivar))
        yhati = basismat * coefi
        yi    = squeeze(y(,,ivar))
        SSE(ivar,) = sum((yi - yhati).^2)
    end
end

#  compute  GCV index

if df < n
    gcv = (SSE./n)./((n - dfscale*df)/n)^2
else
    gcv = NaN
end

#  set up the functional data object

if ndim < 3
    fdobj = fd(coef(1nbasis,),   basisobj, fdnames)
else
    fdobj = fd(coef(1nbasis,,), basisobj, fdnames)
end

#  set up the regression coefficient matrix beta

if q > 0
    ind = (nbasis+1)(nbasis+q)
    if ndim < 3
        beta = coef(ind,)
    else
        beta = coef(ind,,)
    end
else
    beta = []
end

[fdobj, beta, df, gcv, SSE, dev, ...
          penmat, y2cMap, argvals, y]
          
return

}

#  -----------------------------------------------------------------------------
#  -----------------------------------------------------------------------------
#  -----------------------------------------------------------------------------

function [Bvec,Deviance] = ...
              glm.fda(Xmat, Ymat, distr, lamRmat, Wtvec, Bvec0, addterm)
#GLM.FDA Fits a generalized linear model with regularization.
#  This function is called by function smooth.GLM
#  Arguments
#
#  XMAT    ... a N by NBASIS matrix of values of basis functions
#  YMAT    ... May be
#                a N by NCURVE matrix of data to be fitted
#                or, in the binomial case with local sample sizes M.i,
#                a cell array of length 2, the first of which cantains
#                the matrix above containing observed frequencies,
#                and the second of which contains the corresponding
#                sample sizes.  Note that in the binary or Bernoulli case,
#                Y is a matrix of 1's and 0's and the M's are
#                taken to be 1's.
#  DISTR   ... a string indicating which of the five GLM family members
#              is assumed
#              'normal' or 'gaussian' or 'Gaussian'
#              'binomial' or 'binary' or 'Bernoulli'
#              'poisson'
#              'gamma'
#              'inverse gaussian' or 'inverse Gaussian'
#              or a cell array of length(N) with each cell containing
#              a specification of the GLM family of a single observation.
#  LAMRMAT ... a \lambda R, that is, a roughness penalty matrix R of
#              order equal to the number of basis functions used or number
#              of columns of Xmat multiplied by a scalar roughness
#              penalty parameter \lambda
#  WTVEC   ... a vector of prior weights, such as the inverses of the
#              relative variance of each observation.
#  BVEC0   ... starting values for regresscion coefficients
#  ADDTERM ... a addterm with a coefficient fixed at 1.0.
#
#  Returns
#  BVEC     ... Final estimate of coefficients
#  DEVIANCE ... Deviance values
#
#   Last modified 15 September 2014 by Jim Ramsay

#--------------------------------------------------------------------------
#                    Check arguments
#--------------------------------------------------------------------------

if nargin < 3
    error('Number of arguments is less than 3.')
end

#  set default argument values

if nargin < 5, Wtvec    = [] end
if nargin < 6, Bvec0    = [] end
if nargin < 7, addterm  = [] end

if nargin < 4
    error('Less than four arguments for function glm.fda.')
end

#  dimensions of Xmat

[N, nbasis] = size(Xmat)
if iscell(Ymat)
    [Ntmp, ncurve] = size(Ymat{1})
else
    [Ntmp, ncurve] = size(Ymat)
end
if N ~= Ntmp
    error('XMAT and YMAT do not have the same number of rows.')
end

#  define default weight vector WTVEC and check for positivity

if isempty(Wtvec)
    Wtvec = ones(N,1)
end

if any(Wtvec <= 0)
    error('Non-positive values of WTVEC found.')
end

#--------------------------------------------------------------------------
#  Process YMAT and define anonymous functions according to the
#  distribution of Ymat
#     devFn   ... the deviance or loss function,
#                 called after convergence is achieved
#     stdFn   ... the scale factor multiplying D eta
#                 called second inside loop
#     linkFn  ... link function, eta = linkFn(mu),
#                 called prior to loop, maps data space into real line
#     DlinkFn ... derivative of the link function wrt to mu
#                 called first inside loop
#     IlinkFn ... the inverse of the link function IlinkFn[eta] = mu,
#                 called last inside loop, maps eta into data space
# Then set a starting value for the mean mu, avoiding boundary values.
#--------------------------------------------------------------------------

M = []
if ischar(distr)
    #  --------------------------------------------------------------------
    #    All observations are in the same family, distr is a string
    #  --------------------------------------------------------------------
    switch distr
        case 'normal'
            #  Note  Ymat can be any real number, no restrictions
            devFn   = @(mu,Ymat) (Ymat - mu).^2
            stdFn   = @(mu)  ones(size(mu))
            linkFn  = @(mu)  mu
            DlinkFn = @(mu)  ones(size(mu))
            IlinkFn = @(eta) eta
            mu      = Ymat
        case 'binomial'
            if isnumeric(Ymat)
                #  If YMAT a matrix, M is taken to be 1 (set below)
                #  and it must be a binary matrix containing only 0's and 1's
                if any(any(Ymat < 0 | Ymat > 1))
                    error(['For binomial case, YMAT a single column but ', ...
                        ' contains values other than 0 or 1.'])
                end
                M = ones(N,ncurve)
            elseif iscell(Ymat) && length(Ymat) == 2
                #  If YMAT is a cell array of length 2, then first cell
                #  contains a matrix containing the number of successes and
                #  the second cell either contains a matrix of the same
                #  size as the matrix in Ymat{1} or a single positive
                #  integer.
                #  These values or this value is the number of trials M
                #  for a binomial or bernoulli distribution.
                #  M must be a positive integer.
                Freq = Ymat{1}
                M    = Ymat{2}
                if length(M) == 1
                    M = M*ones(N,ncurve)
                end
                if ~all(size(M) == size(Freq))
                    error(['DISTR is binomial and matrix M is not the same ', ...
                        'size as matrix FREQ'])
                end
                if any(any(M < 0))
                    error(['DISTR is binomial and one or more values in M ', ...
                        'have nonpositive values'])
                end
                if any(any(floor(M) ~= M))
                    error(['DISTR is binomial and one or more values in M ', ...
                        'have noninteger values.'])
                end
                #  Redefine YMAT is the proportion of sucesses
                Ymat = Freq./M
            else
                error(['DISTR is binomial and YMAT has incorrect dimensions ', ...
                    ' or is of wrong type.'])
            end
            devFn   = @(mu,Ymat) 2*M.*(Ymat.*log((Ymat+(Ymat==0))./mu) + ...
                (1-Ymat).*log((1-Ymat+(Ymat==1))./(1-mu)))
            stdFn   = @(mu)  sqrt(mu.*(1-mu)./M)
            linkFn  = @(mu)  log(mu./(1-mu))
            DlinkFn = @(mu)  1./(mu.*(1-mu))
            loBnd   = log(eps)
            upBnd   = -loBnd
            IlinkFn = @(eta) 1./(1 + exp(-constrain(eta,loBnd,upBnd)))
            mu      = (M.*Ymat + 0.5)./(M + 1)
        case 'poisson'
            #  Note Ymat must not contain negative numbers
            if any(any(Ymat < 0))
                error('DISTR is poisson and YMAT contains negative values')
            end
            devFn   = @(mu,Ymat) 2*(Ymat.*(log((Ymat+(Ymat==0))./mu)) - ...
                (Ymat - mu))
            stdFn   = @(mu)  sqrt(mu)
            linkFn  = @(mu)  log(mu)
            DlinkFn = @(mu)  1./mu
            loBnd   = log(eps)
            upBnd   = -loBnd
            IlinkFn = @(eta) exp(constrain(eta,loBnd,upBnd))
            mu      = Ymat + 0.25
        case 'gamma'
            #  Note  Ymat must contain only positive numbers
            if any(Ymat <= 0)
                error('DISTR is gamma and Y contains nonpositive values')
            end
            devFn   = @(mu,Ymat) 2*(-log(Ymat./mu) + (Ymat - mu)./mu)
            stdFn   = @(mu) mu
            linkFn  = @(mu)  1./mu
            DlinkFn = @(mu) -1./mu.^2
            loBnd   = eps
            upBnd   = 1/loBnd
            IlinkFn = @(eta) 1./constrain(eta,loBnd,upBnd)
            mu      = max(Ymat, eps)
        case 'inverse gaussian'
            #  Note  Ymat must contain only positive numbers
            if any(any(Ymat <= 0))
                error(['DISTR is inverse gaussian and Y contains ', ...
                    'nonpositive values'])
            end
            devFn   = @(mu,Ymat) ((Ymat - mu)./mu).^2./ Ymat
            stdFn   = @(mu)  mu.^(3/2)
            loBnd   = eps.^(1/2)
            upBnd   = 1/loBnd
            linkFn  = @(mu)  constrain(mu,loBnd,upBnd).^(-2)
            DlinkFn = @(mu)  -2*mu.^(-3)
            IlinkFn = @(eta) constrain(eta,loBnd,upBnd).^(-1/2)
            mu      = Ymat
        otherwise
            error('Distribution name is invalid.')
    end
elseif iscell(distr) && length(distr) == N
    #  --------------------------------------------------------------------
    #    Observations can be in different families, distr is a cell array.
    #  --------------------------------------------------------------------
    mu      = zeros(N,1)
    loBnd   = zeros(N,1)
    upBnd   = zeros(N,1)
    devFn   = cell(N,1)
    stdFn   = cell(N,1)
    linkFn  = cell(N,1)
    DlinkFn = cell(N,1)
    IlinkFn = cell(N,1)
    #  Dealing with the presence of some binomial observations Ymat has
    #  to be a cell with N rows and 2 columns for all data.  Ugh!
    binomwrd = iscell(Ymat) && all(size(Ymat) == [N,2])
    for i=1N
        distri = distr{i}
        if ~ischar(distri)
            error('A distribution specification is not a string.')
        end
        switch distri
            case 'normal'
                #  Note  Ymat can be any real number, no restrictions
                devFn{i}   = @(mu,Ymat) (Ymat - mu).^2
                stdFn{i}   = @(mu)  ones(size(mu))
                linkFn{i}  = @(mu)  mu
                DlinkFn{i} = @(mu)  ones(size(mu))
                IlinkFn{i} = @(eta) eta
                mu(i,) = Ymat(i,)
            case 'binomial'
                if all(isnumeric(Ymat(i,)))
                    #  If YMAT a matrix, M is taken to be 1 (set below)
                    #  and it must be a binary matrix containing only
                    #0's and 1's
                    if any(Ymat(i,) < 0 | Ymat(i,) > 1)
                        error(['For binomial case, YMAT a single column but ', ...
                            ' contains values other than 0 or 1.'])
                    end
                elseif binomwrd
                    Freqi = Ymat{i,1}
                    Mi    = Ymat{i,2}
                    if length(Mi) == 1
                        Mi = Mi*ones(1,ncurve)
                    end
                    if ~all(size(Mi) == size(Freqi))
                        error(['DISTR is binomial and matrix M is not the same ', ...
                            'size as matrix FREQ'])
                    end
                    if any(any(Mi < 0))
                        error(['DISTR is binomial and one or more values in M ', ...
                            'have nonpositive values'])
                    end
                    if any(any(floor(Mi) ~= Mi))
                        error(['DISTR is binomial and one or more values in M ', ...
                            'have noninteger values.'])
                    end
                    #  Redefine YMAT is the proportion of sucesses
                    Ymat(i,) = (Freqi./Mi)
                else
                    error(['DISTR is binomial and YMAT has incorrect dimensions ', ...
                        ' or is of wrong type.'])
                end
                devFn{i}   = @(mu,Ymat) 2*M.*(Ymat.*log((Ymat+(Ymat==0))./mu) + ...
                    (1-Ymat).*log((1-Ymat+(Ymat==1))./(1-mu)))
                stdFn{i}   = @(mu)  sqrt(mu.*(1-mu)./M)
                linkFn{i}  = @(mu)  log(mu./(1-mu))
                DlinkFn{i} = @(mu)  1./(mu.*(1-mu))
                loBnd(i)   = log(eps)
                upBnd(i)   = -loBnd(i)
                IlinkFn{i} = @(eta) 1./(1 + exp(-constrain(eta,loBnd,upBnd)))
                mu(i)      = (M(i).*Ymat(i) + 0.5)./(M(i) + 1)
            case 'poisson'
                #  Note Ymat must not contain negative numbers
                if any(Ymat(i,) < 0)
                    error('DISTR is poisson and YMAT contains negative values')
                end
                devFn{i}   = @(mu,Ymat) 2*(Ymat.*(log((Ymat+(Ymat==0))./mu)) - ...
                    (Ymat - mu))
                stdFn{i}   = @(mu)  sqrt(mu)
                linkFn{i}  = @(mu)  log(mu)
                DlinkFn{i} = @(mu)  1./mu
                loBnd(i)   = log(eps)
                upBnd(i)   = -loBnd(i)
                IlinkFn{i} = @(eta) exp(constrain(eta,loBnd,upBnd))
                mu(i,)    = Ymat(i,) + 0.25
            case 'gamma'
                #  Note  Ymat must contain only positive numbers
                if any(Ymat(i) <= 0)
                    error('DISTR is gamma and Y contains nonpositive values')
                end
                devFn{i}   = @(mu,Ymat) 2*(-log(Ymat./mu) + (Ymat - mu)./mu)
                stdFn{i}   = @(mu) mu
                linkFn{i}  = @(mu)  1./mu
                DlinkFn{i} = @(mu) -1./mu.^2
                loBnd(i)   = eps
                upBnd(i)   = 1/loBnd(i)
                IlinkFn{i} = @(eta) 1./constrain(eta,loBnd,upBnd)
                mu(i,)    = max(Ymat(i,), eps)
            case 'inverse gaussian'
                #  Note  Ymat must contain only positive numbers
                if any(Ymat(i,) <= 0)
                    error(['DISTR is inverse gaussian and Y contains ', ...
                        'nonpositive values'])
                end
                devFn{i}   = @(mu,Ymat) ((Ymat - mu)./mu).^2./ Ymat
                stdFn{i}   = @(mu)  mu.^(3/2)
                loBnd(i)   = eps.^(1/2)
                upBnd(i)   = 1/loBnd(i)
                linkFn{i}  = @(mu)  constrain(mu,loBnd,upBnd).^(-2)
                DlinkFn{i} = @(mu)  -2*mu.^(-3)
                IlinkFn{i} = @(eta) constrain(eta,loBnd,upBnd).^(-1/2)
                mu(i,)    = Ymat(i,)
            otherwise
                error('Distribution name is invalid.')
        end
    end
else
    error('DISTR is neither a string or a cell array of length N.')
end

#--------------------------------------------------------------------------
#                   Initialize mu and eta from Ymat.
#--------------------------------------------------------------------------

# compute eta = E(y) from mu

if ischar(distr)
    eta = linkFn(mu)
else
    eta  = zeros(N,nurve)
    Deta = zeros(N,nurve)
    stdm = zeros(N,nurve)
    for i=1N
        linkFni  = linkFn{i}
        eta(i,) = linkFni(mu(i,))
    end
end

#--------------------------------------------------------------------------
#                        Set up for iterations
#--------------------------------------------------------------------------

iter     = 0
iterLim  = 100
seps     = sqrt(eps)
convcrit = 1e-6
sqrtwt   = sqrt(Wtvec)

#  set up starting value Bvec0 if required

if isempty(Bvec0)
    Bvec0 = zeros(nbasis,ncurve)
end
Bvec = Bvec0

# Enforce limits on mu to guard against an inverse linkFn that doesn't map
# into the support of the distribution.

switch distr
case 'binomial'
    # mu is a probability, so order one is the natural scale, and eps is a
    # reasonable lower limit on that scale (plus it's symmetric).
    muLims = [eps 1-eps]
case {'poisson' 'gamma' 'inverse gaussian'}
    # Here we don't know the natural scale for mu, so make the lower limit
    # small.  This choice keeps mu^4 from underflowing.  No upper limit.
    muLims = realmin.^.25
end

#--------------------------------------------------------------------------
#                       Start of GLM iteration loop
#--------------------------------------------------------------------------

while iter <= iterLim
    iter = iter+1

    # Compute adjusted dependent variable for least squares fit

    if ischar(distr)
        Deta = DlinkFn(mu)
        stdm = stdFn(mu)
    else
        for i=1N
            DlinkFni  = DlinkFn{i}
            stdFni    = stdFn{i}
            mui       = mu(i,)
            Deta(i,) = DlinkFni(mui)
            stdm(i,) = stdFni(mui)
        end
    end
    Zvec = eta + (Ymat - mu).*Deta

    # Compute IRLS weights the inverse of the variance function

    sqrtw = (sqrtwt*ones(1,ncurve))./(abs(Deta).*stdm)

    # Compute coefficient estimates for this iteration - the IRLS step

    Bvec.old   = Bvec
    if ~isempty(addterm)
        Ymattmp = Zvec - addterm
    else
        Ymattmp = Zvec
    end
    Ymatw   = Ymattmp.*sqrtw
    Xmatw   = Xmat.*(sqrtwt*ones(1,nbasis))
    if isempty(lamRmat)
        Mmat = Xmatw'*Xmatw
    else
        Mmat = Xmatw'*Xmatw + lamRmat
    end
    Bvec    = Mmat\Xmatw'*Ymatw
    if ~isempty(addterm)
        eta = Xmat*Bvec + addterm
    else
        eta = Xmat*Bvec
    end
    if ischar(distr)
        mu = IlinkFn(eta)
    else
        for i=1N
            IlinkFni  = IlinkFn{i}
            mu(i,) = IlinkFni(eta(i,))
        end
    end

    # Force mean in bounds, in case the linkFn function is faulty

    if ischar(distr)
        switch distr
            case 'binomial'
                if any(any(mu < muLims(1) | muLims(2) < mu))
                    for j=1m
                        mu(,j) = max(min(mu(,j),muLims(2)),muLims(1))
                    end
                end
            case {'poisson' 'gamma' 'inverse gaussian'}
                if any(any(mu < muLims(1)))
                    for j=1m
                        mu(,j) = max(mu(,j),muLims(1))
                    end
                end
        end
    else
        for i=1N
            distri = distr{i}
            switch distri
                case 'binomial'
                    if any(any(mu(i,) < muLims(1) | muLims(2) < mu(i,)))
                        for j=1m
                            mu(i,j) = max(min(mu(i,j),muLims(2)),muLims(1))
                        end
                    end
                case {'poisson' 'gamma' 'inverse gaussian'}
                    if any(any(mu(i,) < muLims(1)))
                        for j=1m
                            mu(i,j) = max(mu(i,j),muLims(1))
                        end
                    end
            end
        end
    end

    # Check stopping conditions

    if max(max(abs(Bvec-Bvec.old))) < ...
            convcrit*max(max(abs(Bvec.old)))
        break
    end

#     pause

end

#--------------------------------------------------------------------------
#                    end of GLM iteration loop
#--------------------------------------------------------------------------

if iter > iterLim
    warning(['smooth.GLM','Iteration'],'Iteration limit reached.')
end

if nargout > 1
    # Sum components of deviance to get the total deviance.
    if ischar(distr)
        di       = devFn(mu,Ymat)
        Deviance = sum((Wtvec*ones(1,ncurve)).*di)
    else
        Deviance = zeros(N,ncurve)
        for i=1N
            devFni = devFn{i}
            di = devFni(mu(i,),Ymat(,i))
            Deviance(i,) = sum((Wtvec(i)*ones(1,ncurve)).*di)
        end
    end
end
if nargout > 2
    stats = []
end

#  -----------------------------------------------------------------------------
#  -----------------------------------------------------------------------------
#  -----------------------------------------------------------------------------

#  tests for function smooth.GLM

#  ----------------  normal link with no covariates  --------------------

n       = 101
argvals = linspace(0,2*pi,n)'
y0      = sin(2*argvals)
y02     = cos(2*argvals)
sig     = 0.2
y       = y0 + sig.*randn(n,1)
y       = [y, y02 + sig.*randn(n,1)]

basisobj = create.bspline.basis([0,2*pi],n+2)

basismat = eval.basis(argvals, basisobj)

Lfdobj = int2Lfd(2)
penmat = eval.penalty(basisobj,Lfdobj)

lambda  = 1e-1
lamRmat = lambda.*penmat

[coef,Deviance] = glm.fda(basismat, y, 'normal', lamRmat)

fdobj = fd(coef,basisobj)

plotfit.fd(y, argvals, fdobj)

fdParobj = fdPar(basisobj, Lfdobj, lambda)

[fdobj, beta, df, gcv, SSE, dev] = ...
            smooth.GLM(argvals, y, fdParobj, 'family', 'normal')

plotfit.fd(y, argvals, fdobj)

df

gcv

SSE

dev

beta

#  ----------------  normal link with covariates  --------------------

n       = 101
argvals = linspace(0,2*pi,n)'
y0      = sin(2*argvals)
sig     = 0.2
y       = y0 + sig.*randn(n,1)
sigcov  = 0.1
covariates = randn(n,1)
beta    = 1
y       = y + covariates*beta

basisobj = create.bspline.basis([0,2*pi],11)

basismat = eval.basis(argvals, basisobj)

Lfdobj = int2Lfd(2)
penmat = eval.penalty(basisobj,Lfdobj)

lambda  = 1
lamRmat = lambda.*penmat

fdParobj = fdPar(basisobj, Lfdobj, lambda)

[fdobj, beta, df, gcv, SSE, dev] = ...
            smooth.GLM(argvals, y, fdParobj, ...
                       'family', 'normal', 'covariates', covariates)

plotfit.fd(y, argvals, fdobj)

beta

df

gcv

SSE

dev

#  ----------------  binomial link with no covariate  --------------------

n       = 501
argvals = linspace(0,1,n)'
y0      = sin(4*pi*argvals)
sig     = 0.5
y = zeros(n,1)
y(y0 + sig.*randn(n,1) >= 0.0) = 1

basisobj = create.bspline.basis([0,1],13)

basismat = eval.basis(argvals, basisobj)

Lfdobj = int2Lfd(2)
penmat = eval.penalty(basisobj,Lfdobj)

lambda  = 1e-4
lamRmat = lambda.*penmat

[coef,Deviance] = glm.fda(basismat, y, 'binomial', lamRmat)

fdobj = fd(coef,basisobj)

plotfit.fd(y, argvals, fdobj)

fdParobj = fdPar(basisobj, Lfdobj, lambda)

[fdobj, beta, df, gcv, SSE, dev] = ...
                      smooth.GLM(argvals, y, fdParobj, ...
                                       'family', 'binomial')

plot(fdobj)

beta

df

gcv

SSE

dev

stats{}

#  ----------------  poisson link with no covariates  --------------------

n = 101
argvals = linspace(0,2*pi,n)'
y0 = sin(2*argvals)
sig = 0.2
y = y0 + sig.*randn(n,1)
y = exp(y)

basisobj = create.bspline.basis([0,2*pi],53)

lambda = 1e-1
Lfdobj = int2Lfd(2)
fdParobj = fdPar(basisobj, Lfdobj, lambda)

[fdobj, beta, df, gcv, SSE, dev, stats] = ...
            smooth.basis.GLM(argvals, y, fdParobj, ...
                             'family', 'poisson')

plotfit.fd(log(y), argvals, fdobj)

beta

df

gcv

SSE

dev

stats{}






