#' Variance estimation via Bayesian results
#'
#' Use results from the Bayesian interpretation of the GAM to obtain
#' uncertainty estimates. See Wood (2006).
#'
#' NB. We include uncertainty in the detection function using the delta method
#'   so INDEPENDENCE is still assumed between the two variance components
#'
#' @param dsm.obj an object returned from running \code{\link{dsm.fit}}.
#' @param pred.data either: a single prediction grid or list of prediction 
#'        grids. Each grid should be a \code{data.frame} with the same 
#'        columns as the original data.
#' @param off.set a a vector or list of vectors with as many elements as there 
#'        are in \code{pred.data}. Each vector is as long as the number of
#'        rows in the corresponding element of \code{pred.data}. These give
#'        the area associated with each prediction point. 
#' @param seglen.varname name for the column which holds the segment length 
#'        (default value "Effort"). 
#' @param type.pred should the predictions be on the "response" or "link" scale?
#'        (default "response").
#' @return a list with elements
#'         \tabular{ll}{\code{model} \tab the fitted model object\cr
#'                      \code{pred.var} \tab covariances of the regions given
#'                      in \code{pred.data}. Diagonal elements are the 
#'                      variances in order\cr
#'                      \code{bootstrap} \tab logical, always \code{FALSE}\cr
#'                      \code{pred.data} \tab as above\cr
#'                      \code{off.set} \tab as above\cr
#'                      \code{model}\tab the fitted model with the extra term\cr
#'                      \code{dsm.object} \tab the original model, as above
#'                      }
#' @author David L. Miller.
# @references 
#' @export

### TODO
# write it!
# references


dsm.var.gam<-function(dsm.obj, pred.data,off.set, 
    seglen.varname='Effort', type.pred="response") {

  pred.data.save<-pred.data
  off.set.save<-off.set

  # make sure if one of pred.data and off.set is not a list we break
  # if we didn't have a list, then put them in a list so everything works
  if(is.data.frame(pred.data) & is.vector(off.set)){
    pred.data <- list(pred.data)
    off.set <- list(off.set)
#    pred.data[[1]] <- pred.data
#    off.set[[1]] <- off.set
  }else if(is.list(off.set)){
    if(length(pred.data)!=length(off.set)){
      stop("pred.data and off.set don't have the same number of elements")
    }
  }

  # and the gam
  gam.obj <- dsm.obj$result

  # run the model
  fit.with.pen <- gam.obj

  cft <- coef(fit.with.pen)

  dpred.db <- matrix(0, length(pred.data), length(cft))
  
  # depending on whether we have response or link scale predictions...
  if(type.pred=="response"){
      tmfn <- gam.obj$family$linkinv
      dtmfn <- function(eta){sapply(eta, numderiv, f=tmfn)}
  }else if(type.pred=="link"){ 
      tmfn <- identity
      dtmfn <- function(eta){1}
  }

  # loop over the prediction grids
  for( ipg in seq_along(pred.data)) {

    ### fancy lp matrix stuff
    # set the offset to be zero here so we can use lp
    pred.data[[ipg]]$off.set<-rep(0,nrow(pred.data[[ipg]]))

    lpmat <- predict( fit.with.pen, newdata=pred.data[[ ipg]], type='lpmatrix')
    lppred <- lpmat %**% cft

    # if the offset is just one number then repeat it enough times 
    if(length(off.set[[ipg]])==1){
      this.off.set <- rep(off.set[[ipg]],nrow(pred.data[[ipg]]))
    }else{
      this.off.set <- off.set[[ipg]]
    }

    dpred.db[ipg,] <- this.off.set %**% (dtmfn(lppred)*lpmat)
  } 

  # "'vpred' is the covariance of all the summary-things." - MVB  
  # so we want the diagonals if length(pred.data)>1
  # A B A^tr 
  vpred <- dpred.db %**% tcrossprod(vcov(fit.with.pen), dpred.db) 

  result <- list(pred.var = vpred,
                 bootstrap = FALSE,
                 pred.data = pred.data.save,
                 off.set = off.set.save,
                 model = fit.with.pen,
                 dsm.object = dsm.obj,
                 seglen.varname=seglen.varname, 
                 type.pred=type.pred
                )

  class(result) <- "dsm.var"

  return(result)
}