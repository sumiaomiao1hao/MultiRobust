# Multiple imputation
MI.glm <- function(imp.model, L, data)
{
  n <- NROW(data)
  K <- length(imp.model) # No. of SETS of imputation models
  newdata <- vector(mode = "list", length = K)
  imp.glm <- eval.glm.KV(imp.model = imp.model, data = data)

  for (k in 1:K){
    newdat <- NULL
    imp.modelk <- imp.model[[k]]
    V <- length(imp.modelk)

	for (l in 1:L){
      newdatl <- matrix(0, n, V)
      mis.names <- rep(0, V)
      for (v in 1:V){
        imp.modelkv <- imp.glm[[k]][[v]]
        fam <- imp.modelkv$family$family
        # link <- imp.modelkv$family$link
        # coeff <- coef(imp.modelkv)
		wts.tmp <- imp.modelkv$prior.weights
		if (is.null(wts.tmp)) wts.tmp <- rep(1, n)
        impvar <- paste(imp.modelkv$formula[[2L]]) # name of the variable being imputed of kth imputation model
        mis.names[v] <- impvar
        m <- predict(imp.modelkv, newdata = data, type = "response")

        if (fam == "gaussian"){
          vars <- deviance(imp.modelkv) / df.residual(imp.modelkv) / wts.tmp
          imp <- rnorm(n, mean = m, sd = sqrt(vars))
        }
        
		else if (fam == "binomial"){
		  if (any(m < 0) | any(m > 1)) 
            stop(paste("imputation model ", v, " in list ", k, " is not appropriate, estimated probability should be within [0,1] for 'binomial' family; specify a different imputation model"))
          if (any(wts.tmp %% 1 != 0))
            stop("cannot simulate from non-integer prior.weights")

          if (!is.null(md <- imp.modelkv$model)){
            y <- model.response(md)
            if(is.factor(y)){
              imp <- factor(1 + rbinom(n, size = 1, prob = m), labels = levels(y))
            } else
            imp <- rbinom(n, size = wts.tmp, prob = m)/wts.tmp
          } else imp <- rbinom(n, size = wts.tmp, prob = m)/wts.tmp

        }
        
		else if (fam == "poisson"){
		  if (any(m <= 0)) 
            stop(paste("imputation model ", v, " in list ", k, " is not appropriate, estimated mean should be positive for 'Poisson' family; specify a different imputation model"))
		  imp <- rpois(n, lambda = m)
		}

        else if (fam == "Gamma"){
          # if(!requireNamespace("MASS", quietly = TRUE))
          #   stop("need CRAN package 'MASS' for simulation from the 'Gamma' family")
          # shape <- MASS::gamma.shape(imp.modelkv)$alpha * wts.tmp
		  shape <- 1 / summary(imp.modelkv)$dispersion * wts.tmp
          if (any(shape <= 0) | any(shape / m <= 0)) 
		    stop(paste("imputation model ", v, " in list ", k, " is not appropriate, estimated shape and rate should be positive for 'Gamma' family; specify a different imputation model"))
          imp <- rgamma(n, shape = shape, rate = shape / m)
        }

        else if (fam == "inverse.gaussian"){
          if(!requireNamespace("SuppDists", quietly = TRUE))
            stop("need CRAN package 'SuppDists' for simulation from the 'inverse.gaussian' family")
		  disp <- summary(imp.modelkv)$dispersion
          if (any(m <= 0) | any(disp <= 0)) 
		    stop(paste("imputation model ", v, " in list ", k, " is not appropriate, estimated mean should be positive for 'inverse.gaussian' family; specify a different imputation model"))
          imp <- SuppDists::rinvGauss(n, nu = m, lambda = wts.tmp / disp)
        }
		
        newdatl[ , v] <- imp
      }
      newdatl <- data.frame(newdatl)
      colnames(newdatl) <- mis.names
      newdat <- rbind(newdat, cbind(1:n, rep(l,n), newdatl, data[ , -match(mis.names, names(data))]))
    }

    names(newdat)[1] <- "obs"
    names(newdat)[2] <- "L"
    newdata[[k]] <- data.frame(newdat)
  }
  return(newdata)
}
