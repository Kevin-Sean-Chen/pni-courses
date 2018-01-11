data {

    // Metadata
    int  N;                            // number of subjects
    int  B;                            // number of blocks
    int  T;                            // number of trials
    
    // Data
    int  X[N, B, T, 2];                // presented machines, range [1-9]
    int  Y[N, B, T];                   // choice data, range [-1-2] where missing = -1
    real R[N, B, T];                   // outcome data, range {0.00, 0.25}
    real M[N, B, 3];                   // Mood data, range (-1, 1)

    // Initial values
    real h12[N, 2];                    // Initial h-values, blocks 1-2, arctanh transformed
    
}
parameters {

    // Group-level (hyper)parameters
    vector[4] mu_pr;
    vector<lower=0>[4] sigma; 

    // Subject-level parameters (raw)
    vector[N] beta_pr;
    vector[N] eta_v_pr;
    vector[N] eta_h_pr;
    vector[N] f_pr;
    
    // Missing data
    vector[N] h3;

}
transformed parameters {

    // Subject-level parameters (transformed)
    vector<lower=0,upper=50>[N]    beta;
    vector<lower=0,upper=1>[N]     eta_v;
    vector<lower=0,upper=1>[N]     eta_h;
    vector[N]     f;
    
    for (i in 1:N) {
        beta[i]  = Phi_approx( mu_pr[1] + sigma[1] * beta_pr[i] ) * 50;
        eta_v[i] = Phi_approx( mu_pr[2] + sigma[2] * eta_v_pr[i] );
        eta_h[i] = Phi_approx( mu_pr[3] + sigma[3] * eta_h_pr[i] );
        f[i] = exp( (mu_pr[4] + sigma[4] * f_pr[i]) / 2 );
    }
    
}
model {
    
    // Group-level priors
    mu_pr ~ normal(0, 1);
    sigma ~ gamma(1, 0.5);
    
    // Subject-level priors
    beta_pr ~ normal(0, 1);
    eta_v_pr ~ normal(0, 1);
    eta_h_pr ~ normal(0, 1);
    f_pr ~ normal(0, 1);
    h3 ~ normal(0, 1);
    
    // Likelihood
    for (i in 1:N) {
    
        // Generated data
        vector[9] Q;
        Q = rep_vector(0, 9);
  
        for (j in 1:B) {
        
            real h;
            real m;
            
            if ( j < 3 ) { 
                h = h12[i,j];
            } else { 
                h = h3[i];
            }
            m = tanh(h);
        
            for (k in 1:T) {
                        
                real delta;
                delta = 0;
                        
                // Execute only for non-missing responses.
                if ( Y[i,j,k] > 0 ) {
                
                    // Likelihood of observed choice.
                    Y[i,j,k] ~ categorical_logit( beta[i] * Q[X[i,j,k,:]] );
                    
                    // Compute reward prediction error.
                    delta = (f[i] ^ m) * R[i, j, k] - Q[X[i,j,k, Y[i,j,k]]];
                    
                    // Update expectations.
                    Q[X[i,j,k, Y[i,j,k]]] += eta_v[i] * delta;
                
                    // Update history of rewards.
                    h += eta_h[i] * (delta - h);
                    
                    // Update mood.
                    m = tanh( h );
                
                }
                
                // Predict likelihood of mood.
                if ( k == 7 ){
                    M[i,j,1] ~ normal( m, 0.1 );
                } else if ( k == 21 ) {
                    M[i,j,2] ~ normal( m, 0.1 );
                } else if ( k == 35 ) {
                    M[i,j,3] ~ normal( m, 0.1 );
               }
                
            }
        
        }
    
    }
    
}
generated quantities {

    // Transformed group-level parameters.
    real mu_beta;            // Inverse temperature
    real mu_eta_v;           // Learning rate
    real mu_eta_h;           // History rate
    real mu_f;               // Mood bias
    
    // Posterior predictive check / log-likelihood values.
    int  Y_pred[N, B, T];    // Simulated choice data
    real M_pred[N, B, 3];    // Simulated mood data
    vector[N] log_lik;       // Model log-likelihood
    
    // Transform parameters.
    mu_beta = Phi_approx( mu_pr[1] ) * 50;
    mu_eta_v = Phi_approx( mu_pr[2] );
    mu_eta_h = Phi_approx( mu_pr[3] );
    mu_f = exp( mu_pr[4] / 2 );
    
    // Initialize log-likelihood.
    log_lik = rep_vector(0, N);

    { // Local section (to avoid saving Q-values)
    
        for (i in 1:N) {

            // Generated data
            vector[9] Q;
            Q = rep_vector(0, 9);

            for (j in 1:B) {

                real h;
                real m;

                if ( j < 3 ) { 
                    h = h12[i,j];
                } else { 
                    h = h3[i];
                }
                m = tanh(h);

                for (k in 1:T) {

                    real delta;
                    delta = 0;

                    // Execute only for non-missing responses.
                    if ( Y[i,j,k] > 0 ) {

                        // Log-likelihood of observed choice.
                        log_lik[i] += categorical_logit_lpmf( Y[i,j,k] | beta[i] * Q[X[i,j,k,:]] );

                        // Predict choice given current model.
                        Y_pred[i,j,k] = categorical_logit_rng( beta[i] * Q[X[i,j,k,:]] );

                        // Compute reward prediction error.
                        delta = (f[i] ^ m) * R[i, j, k] - Q[X[i,j,k, Y[i,j,k]]];

                        // Update expectations.
                        Q[X[i,j,k, Y[i,j,k]]] += eta_v[i] * delta;

                        // Update history of rewards.
                        h += eta_h[i] * (delta - h);

                        // Update mood.
                        m = tanh( h );

                    }

                    // Predict likelihood of mood.
                    if ( k == 7 ){
                        M_pred[i,j,1] = m;
                    } else if ( k == 21 ) {
                        M_pred[i,j,2] = m;
                    } else if ( k == 35 ) {
                        M_pred[i,j,3] = m;
                   }
                   
               }
                
            }
        
        }
    
    }
    
}