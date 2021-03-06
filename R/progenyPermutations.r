#'Compute progeny pathway scores and assesses significance based on permutations
#'
#'@param df A data.frame of n*m+1 dimension, where n is the number of omic
#'features to be considered and m is the number of samples/contrasts.
#'The first column should be the identifiers of the omic features. 
#'These identifiers must be coherent with the identifiers of the weight matrix.
#'@param weight_matrix A progeny coefficient matrix. the first column should be
#'the identifiers of the omic features and should be coherent with 
#'the identifiers provided in df.
#'@param k The number of permutations to be performed to generate
#'the null-distribution used to estimate the significance of progeny scores.  
#'The default value is 10000.
#'@param z_scores if true, the z-scores will be returned for 
#'the pathway activity estimations. Else, the function returns 
#'a normalized z-score value between -1 and 1.
#'@param get_nulldist if true, the null score distribution used for 
#'normalization will be returned along with the actual normalized score data 
#'frame.
#'@importFrom stats complete.cases sd ecdf
#'@export 
#'@return This function returns a list of two elements. The first element is 
#'a data frame of p*m+1 dimensions, where p is the number of progeny pathways,
#'and m is the number of samples/contrasts. Each cell represents the 
#'significance of a progeny pathway score for one sample/contrast. The 
#'significance ranges between -1 and 1. The significance is equal to x*2-1, x 
#'being the quantile of the progeny pathway score with respect to the null 
#'distribution. Thus, this significance can be interpreted as the equivalent of 
#'1-p.value two-sided test over an empirical distribution) with the sign 
#'indicating the direction of the regulation. The second element is the null 
#'distribution list (a null distribution is generated for each sample/contrast).
#'@examples
#' # use example gene expression matrix
#' gene_expression <- as.matrix(read.csv(system.file("extdata", 
#' "human_input.csv", package = "progeny"), row.names = 1))
#'
#' # calculate pathway activities
#' progeny(gene_expression, scale=TRUE, organism="Human", top=100, perm=10000)
#'@export
progenyPerm <- 
    function(df,weight_matrix,k = 10000, z_scores = TRUE,  get_nulldist = FALSE)
{
    resList <- list()
    if(get_nulldist) {
         nullDist_list <- list()
    }
  
    for(i in 2:length(df[1,])) {
        current_df <- df[,c(1,i)]
        current_df <- current_df[complete.cases(current_df),]
        t_values <- current_df[,2]
        current_weights <- weight_matrix
        names(current_df)[1] <- "ID"
        names(current_weights)[1] <- "ID"
    
        common_ids <- merge(current_df, current_weights, by = "ID")
        common_ids <- as.character(common_ids$ID)

        row.names(current_df) <- current_df$ID 
        current_df <- as.data.frame(current_df[common_ids,-1])
        row.names(current_weights) <- current_weights$ID
        current_weights <- as.data.frame(current_weights[common_ids,-1])
        current_mat <- as.matrix(current_df)
        current_weights <- t(current_weights)
    
        scores <- as.data.frame(current_weights %*% current_mat)
        null_dist_t <- replicate(k, sample(t_values,length(current_mat[,1]), 
            replace = FALSE))
        null_dist_scores <- current_weights %*% null_dist_t
    
        if(get_nulldist) {
            nullDist_list[[i-1]] <- null_dist_scores
        }
    
        if(z_scores) {
            scores$mean <- apply(null_dist_scores,1,mean)
            scores$sd <- apply(null_dist_scores,1,sd)
            resListCurrent <- (scores[,1]-scores[,2])/scores[,3]
            names(resListCurrent) <- names(weight_matrix[,-1])
            resList[[i-1]] <- resListCurrent
        } else {
            for(j in seq(1, length(weight_matrix[,-1]))) {
                ecdf_function <- ecdf(null_dist_scores[j,])
                scores[j,1] <- ecdf_function(scores[j,1])
        }
        score_probas <- scores*2-1
        resListCurrent <- score_probas[,1]
        names(resListCurrent) <- names(weight_matrix[,-1])
        resList[[i-1]] <- resListCurrent
        }
    }
    names(resList) <- colnames(df)[-1]
    resDf <- as.data.frame(resList)
    if(get_nulldist) {
        names(nullDist_list) <- names(df[,-1])
        return(list(resDf, nullDist_list))
    } else {
        return(t(resDf))
    }
}
