#########################################
# Tuberculosis model - MCMC and inlabru
#########################################

set.seed(seed) # Set the seed (found in the Master script).

# Part One: Setup

print(Sys.time())

# Set up necessary data for the ICAR prior.
adjacency=unlist(neighbourhood)
n_adj=card(neighbourhood)
l_adj=length(adjacency)
weights=rep(1,l_adj)

TB_N=length(TBdata$TB) # Number of observations.
n_regions=length(n_adj) # Number of regions.

total_obs=c(sum(TBdata$TB[1:n_regions]),sum(TBdata$TB[(1:n_regions)+n_regions]),sum(TBdata$TB[(1:n_regions)+2*n_regions]))

# Set up index for spatial parameters rho and delta.
region_index=numeric(n_regions)
for(i in 1:n_regions){
  region_index[i]=which(brasil_micro$COD_MICRO==TBdata$Identifier[i])
}
region_index=rep(region_index,3)


# Create polynomials.
poly_tim=poly(TBdata$Timeliness,3)
poly_unem=poly(TBdata$Unemployment,2)
poly_den=poly(TBdata$Density,2)
poly_urb=poly(TBdata$Urbanisation,2)

# Center indigenous.
tran_ind=TBdata$Indigenous-mean(TBdata$Indigenous)

# 
# # Produce a map of the tuberculosis cases.
brasil_map=map_data(brasil_micro)
brasil_map$region=as.numeric(brasil_map$region)
brasil_map$region[brasil_map$region<=187]=brasil_map$region[brasil_map$region<=187]+1
brasil_map$incidence=100000*(brasil_micro$TBcases.2012/brasil_micro$Pop2012+brasil_micro$TBcases.2013/brasil_micro$Pop2013+brasil_micro$TBcases.2014/brasil_micro$Pop2014)[brasil_map$region]

brazil.map = ggplot() + geom_polygon(data = brasil_map, aes(x=long, y = lat, group = group,fill=incidence))+ggtitle('New Tuberculosis Cases 2012-2014') +
  theme_void() +
  scale_fill_distiller(palette=col.pal, direction = +1,name="Number of Cases")+ # limits = c(min(brasil_map$incidence), max(brasil_map$incidence)),breaks=c(0,250,500,750,1000), name="Number of Cases")+ #,guide = guide_legend( keyheight = unit(3, units = "mm"), keywidth=unit(12, units = "mm"), label.position = "bottom", title.position = 'top', nrow=1))+#viridis(trans = "log", breaks=c(25,50,100,200), name="Number of Cases", guide = guide_legend( keyheight = unit(3, units = "mm"), keywidth=unit(12, units = "mm"), label.position = "bottom", title.position = 'top', nrow=1) ) +
  labs(
    title = "Recorded Tuberculosis Cases",
    subtitle = "Total per 100,000 People, 2012-2014"
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),
    
    plot.title = element_text(size= 22, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.43, l = 2, unit = "cm")),
    plot.caption = element_text( size=12, color = "#4e4d47", margin = margin(b = 0.3, r=-99, unit = "cm") ),
    
    legend.position = c(0.75, 0.18)
  ) +
  coord_map()
#brazil.map
#ggsave('mcmc_data.pdf',device='pdf',width=6,height=6)

# Execution

# Model code.
TB_code=nimbleCode({ 
  for(i in 1:n){
    pi[i] <- ilogit(b[1]+tim[i,1]*b[2]+tim[i,2]*b[3]+tim[i,3]*b[4])
    lambda[i] <- exp(log(pop[i])+
                       a[1]+
                       a[2]*unem[i,1]+a[3]*unem[i,2]+
                       a[4]*urb[i,1]+a[5]*urb[i,2]+
                       a[6]*den[i,1]+a[7]*den[i,2]+
                       a[8]*ind[i]+
                       phi[index[i]]+theta[index[i]])
    z[i] ~ dpois(pi[i]*lambda[i])
  }
  for(j in 1:R){
    theta[j] ~ dnorm(0,1)
  }
  phi[1:R] ~ dcar_normal(adj=adj[1:l_adj], num=n_adj[1:R], tau=tau,zero_mean=1)
  a[1] ~ dnorm(-8,sd=1)
  for(i in 2:8){
    a[i] ~ dnorm(0,sd=10)
  }
  b[1] ~ dnorm(2,sd=0.6)
  for(i in 2:4){
    b[i] ~ dnorm(0,sd=10)
  }
  tau ~ dgamma(1, 0.00005)
})

# Set up data for NIMBLE.
TB_constants=list(n=TB_N,pop=TBdata$Population,ind=tran_ind,n_adj=n_adj,
                  adj=adjacency,tim=poly_tim,unem=poly_unem,urb=poly_urb,den=poly_den,
                  R=n_regions,index=region_index,w=weights,l_adj=length(adjacency))
TB_data=list(z=TBdata$TB)

# Set initial values.
TB_inits1=list(tau=1,a=c(-7,rep(-0.1,7)),b=c(1.8,rep(0.1,3)),
               phi=rnorm(n_regions,0,1),theta=rnorm(n_regions,0,0.25))
TB_inits2=list(tau=0.75,a=c(-7,rep(0.1,7)),b=c(1.8,rep(-0.1,3)),
               phi=rnorm(n_regions,0,0.75),theta=rnorm(n_regions,0,0.5))
TB_inits3=list(tau=0.5,a=c(-9,rep(-0.1,7)),b=c(2.2,rep(0.1,3)),
               phi=rnorm(n_regions,0,0.5),theta=rnorm(n_regions,0,0.75))
TB_inits4=list(tau=0.25,a=c(-9,rep(0.1,7)),b=c(2.2,rep(-0.1,3)),
               phi=rnorm(n_regions,0,0.25),theta=rnorm(n_regions,0,1))
TB_inits=list(chain1=TB_inits1,chain2=TB_inits2,chain3=TB_inits3,chain4=TB_inits4)

# Build the model.
TB_model <- nimbleModel(TB_code, TB_constants,TB_data,TB_inits)
TB_compiled_model <- compileNimble(TB_model,resetFunctions = TRUE)

# Set up samplers.
TB_mcmc_conf <- configureMCMC(TB_model,monitors=c('a','b','tau',
                                                  'pi','lambda','phi','theta'),useConjugacy = TRUE)
TB_mcmc_conf$removeSamplers(c('a[1]','b[1]','tau'))
TB_mcmc_conf$addSampler(target=c('a[1]','b[1]','tau'),type='AF_slice')
#TB_mcmc_conf$addSampler(target=c('tau'),type='AF_slice')

TB_mcmc<-buildMCMC(TB_mcmc_conf)
TB_compiled_mcmc<-compileNimble(TB_mcmc, project = TB_model,resetFunctions = TRUE)

# Run the model (hours).
TB_samples=runMCMC(TB_compiled_mcmc,inits=TB_inits,
                   nchains = 4, nburnin=400000,niter = 800000,samplesAsCodaMCMC = TRUE,thin=40,
                   summary = FALSE, WAIC = FALSE,setSeed=c(seed,2*seed,3*seed,4*seed))

# # Run the model just for testing.
# TB_samples=runMCMC(TB_compiled_mcmc,inits=TB_inits,
#                    nchains = 4, nburnin=40,niter = 80,samplesAsCodaMCMC = TRUE,thin=40,
#                    summary = FALSE, WAIC = FALSE,setSeed=c(seed,2*seed,3*seed,4*seed))




gelman <- gelman.diag(TB_samples[,c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]','a[8]',
                          'b[1]','b[2]','b[3]','b[4]','tau')])

print(gelman)


#  Model Checking

# Construct adjacency matrix:
TB_A=matrix(0,nrow=n_regions,ncol=n_regions)
TB_A[1,adjacency[1:n_adj[1]]]=1
for(i in 2:n_regions){
  TB_A[i,adjacency[(sum(n_adj[1:(i-1)])+1):(sum(n_adj[1:(i-1)])+n_adj[i])]]=1
}
TB_D <- diag(rowSums(TB_A))

n_sim=10000 # Number of prior samples to simulate.
#n_sim=4 # just for model checking. 

# Simulate from parameter priors.
prior_alpha=cbind(rnorm(n_sim,-8,1),
                  rnorm(n_sim,0,10),
                  rnorm(n_sim,0,10),
                  rnorm(n_sim,0,10),
                  rnorm(n_sim,0,10),
                  rnorm(n_sim,0,10),
                  rnorm(n_sim,0,10),
                  rnorm(n_sim,0,10))
prior_beta=cbind(rnorm(n_sim,2,0.6),
                 rnorm(n_sim,0,10),
                 rnorm(n_sim,0,10),
                 rnorm(n_sim,0,10))
prior_tau= rgamma(n_sim,1, 0.00005)

# Simulate random effects.
prior_phi=prior_theta=matrix(nrow=n_sim,ncol=n_regions)


for(i in 1:n_sim){
  prior_theta[i,]=rnorm(n_regions,0,1)
  # Spatial effect phi can be slow to simulate.
  prior_phi[i,]=ricar_compiled(prior_tau[i]*(TB_D-TB_A),.Machine$double.eps)
}

# Compute prior distributions for pi and lambda.
prior_pi=expit(prior_beta%*%t(cbind(1,poly_tim)))
prior_lambda=exp(log(TBdata$Population)+prior_alpha%*%t(cbind(1,poly_unem,poly_urb,poly_den,tran_ind))+prior_theta[,region_index]+prior_phi[,region_index])

# Simulate z.
prior_z=t(apply(prior_lambda*prior_pi,1,function(x)rpois(TB_N,x)))
prior_rate=t(apply(prior_z,1,function(x) x/TBdata$Population))
prior_lmse=apply(prior_z,1,function(x) log(mean((x-TBdata$TB)^2)))

# Combine MCMC chains.
TB_mcmc=do.call('rbind',TB_samples)


# Compute posterior quantities.
posterior_phi=TB_mcmc[,(13+TB_N):(12+TB_N+n_regions)]
posterior_theta=TB_mcmc[,(14+2*TB_N+n_regions):(13+2*TB_N+2*n_regions)]
posterior_lambda=TB_mcmc[,(13):(12+TB_N)]
posterior_pi=TB_mcmc[,(13+TB_N+n_regions):(12+2*TB_N+n_regions)]


# Simulate z.
posterior_z=t(apply(posterior_pi*posterior_lambda,1,function(x)rpois(TB_N,x)))
posterior_lmse=apply(posterior_z,1,function(x) log(mean((x-TBdata$TB)^2)))
posterior_rate=t(apply(posterior_z,1,function(x) x/TBdata$Population))

# Simulate y values.
posterior_y=t(apply(posterior_lambda,1,function(x)rpois(TB_N,x)))
posterior_total_y=t(apply(posterior_y,1,function(x)c(sum(x[1:n_regions]),sum(x[(1:n_regions)+n_regions]),sum(x[(1:n_regions)+2*n_regions]))))
posterior_total_extra_y=t(apply(posterior_total_y,1,function(x) x-total_obs))

# Ratio of mean log mean squared errors.
mean(exp(posterior_lmse))/mean(exp(prior_lmse))

# # Fitted values plot.
ggplot(data.frame(x=100000*TBdata$TB/TBdata$Population,m=100000*apply(posterior_rate,2,mean))) +
  geom_abline(slope=1,intercept=0)+geom_point(aes(x=x,y=m),col=col.pal.green,alpha=0.4) +
  labs(
    title = "Recorded Tuberculosis Cases",
    subtitle ="per 100,000 People",
    y=expression('Mean Predicted Value'),
    x=expression('Observed Value')
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),

    plot.title = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 12, hjust=0.01, color = "#4e4d47", margin = margin(b = 0.1, t = 0.43, l = 2, unit = "cm"))
  )
ggsave('fitted.pdf',device='pdf',width=4.5,height=3)

# Coverage of posterior prediction intervals for recorded counts.
# 
paste('Coverage of 95% posterior prediction intervals for z ',
      round(mean(TBdata$TB>=apply(posterior_z,2,quantile,0.025)&TBdata$TB<=apply(posterior_z,2,quantile,0.975)),3))

# Predictive quantile plot.
ggplot(data.frame(x=TBdata$TB,
                  l=apply(posterior_z,2,quantile,0.025)-TBdata$TB,
                  u=apply(posterior_z,2,quantile,0.975)-TBdata$TB)) +
  geom_hline(yintercept=0)+
  geom_point(aes(x=x,y=l),col=col.pal.blue) +
  geom_point(aes(x=x,y=u),col=col.pal.green) +
  labs(
    title = "Recorded Tuberculosis Cases",
    y=expression('Predicted '*tilde(z)['t,s']*' - Observed '*z['t,s']),
    x=expression('Observed Number of Cases '*z['t,s'])
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),

    plot.title = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = 0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 12, hjust=0.01, color = "#4e4d47", margin = margin(b = 0.1, t = 0.43, l = 2, unit = "cm"))
  )+scale_x_sqrt(limits=c(0,10000))+
  scale_color_brewer(palette = col.pal)
ggsave('mcmc_z_plot.pdf',device='pdf',width=4.5,height=3)


# Produce predictive checking plots.
m1=ggplot(data.frame(prior=log(apply(prior_z,1,mean)),post=log(apply(posterior_z,1,mean))))+
  stat_density(aes(x=prior),adjust=2,alpha=0.4,fill=col.pal.green)+
  geom_vline(xintercept=log(mean(TBdata$TB)),colour="#22211d")+
  labs(
    y='Prior Density',
    x=expression(log('Sample Mean'))
  )+
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA)
  )
m2=ggplot(data.frame(prior=log(apply(prior_z,1,mean)),post=log(apply(posterior_z,1,mean))))+
  stat_density(aes(x=post),adjust=2,alpha=0.4,fill=col.pal.green)+
  geom_vline(xintercept=log(mean(TBdata$TB)),colour="#22211d")+
  labs(
    y='Posterior Density',
    x=expression(log('Sample Mean'))
  )+
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA)
  )
v1=ggplot(data.frame(prior=log(apply(prior_z,1,var)),post=log(apply(posterior_z,1,var))))+
  stat_density(aes(x=prior),adjust=2,alpha=0.4,fill=col.pal.green)+
  geom_vline(xintercept=log(var(TBdata$TB)),colour="#22211d")+
  labs(
    y='Prior Density',
    x=expression(log('Sample Variance'))
  )+
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA)
  )
v2=ggplot(data.frame(prior=log(apply(prior_z,1,var)),post=log(apply(posterior_z,1,var))))+
  stat_density(aes(x=post),adjust=2,alpha=0.4,fill=col.pal.green)+
  geom_vline(xintercept=log(var(TBdata$TB)),colour="#22211d")+
  labs(
    y='Posterior Density',
    x=expression(log('Sample Variance'))
  )+
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA)
  )
e1=ggplot(data.frame(prior=prior_lmse,post=posterior_lmse))+
  stat_density(aes(x=prior),adjust=2,alpha=0.4,fill=col.pal.green)+
  labs(
    y='Prior Density',
    x=expression(log('Mean Squared Error'))
  )+
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA)
  )+scale_x_continuous(limits=c(10,35))
e2=ggplot(data.frame(prior=prior_lmse,post=posterior_lmse))+
  stat_density(aes(x=post),adjust=2,alpha=0.4,fill=col.pal.green)+
  labs(
    y='Posterior Density',
    x=expression(log('Mean Squared Error'))
  )+
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA)
  )

pdf(file='mcmc_check.pdf',width=9,height=4.5)
multiplot(m1,m2,v1,v2,e1,e2,cols=3)
dev.off()

# Part Four: Results
pi_means <- apply(posterior_pi,2,mean)
inverse_index=sort(region_index[1:n_regions],index.return=TRUE)$ix
pi_spatial <- cbind(pi_means[inverse_index],pi_means[inverse_index+557],pi_means[inverse_index+1114]) %>%
  logit() %>% apply(.,1,mean) %>% expit()

# # Produce spatial effect plots.
brasil_map$phi=apply(posterior_phi,2,mean)[brasil_map$region]
brasil_map$theta=apply(posterior_theta,2,mean)[brasil_map$region]
brasil_map$combined=brasil_map$phi+brasil_map$theta
brasil_map$pi=pi_spatial[brasil_map$region]

phi=ggplot() + geom_polygon(data = brasil_map, aes(x=long, y = lat, group = group,fill=phi)) +
  theme_void() +
  scale_fill_distiller(palette=col.pal, direction = +1, name=expression(phi[s]),breaks=c(-1,-0.5,0,0.5,1,1.5))+ #viridis( breaks=c(-0.5,-0.25,0,0.25,0.5), name=expression(phi[s]), guide = guide_legend( keyheight = unit(3, units = "mm"), keywidth=unit(8, units = "mm"), label.position = "bottom", title.position = 'top', nrow=1) ) +
  labs(
    title = "Structured Spatial Effect"
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),

    plot.title = element_text(size= 22, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.43, l = 2, unit = "cm")),
    plot.caption = element_text( size=12, color = "#4e4d47", margin = margin(b = 0.3, r=-99, unit = "cm") ),

    legend.position = c(0.75, 0.18)
  ) +
  coord_map()
phi
ggsave('mcmc_phi_spatial_map.pdf',device='pdf',width=6,height=6)

theta=ggplot() + geom_polygon(data = brasil_map, aes(x=long, y = lat, group = group,fill=theta)) +
  theme_void() +
  scale_fill_distiller(palette=col.pal, direction = +1,name=expression(theta[s]),breaks=c(-0.5,-0.25,0,0.25,0.5,0.75))+#viridis( breaks=c(-0.05,-0.025,0,0.025,0.05), name=expression(theta[s]), guide = guide_legend( keyheight = unit(3, units = "mm"), keywidth=unit(8, units = "mm"), label.position = "bottom", title.position = 'top', nrow=1) ) +
  labs(
    title = "Unstructured Spatial Effect"
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),

    plot.title = element_text(size= 22, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.43, l = 2, unit = "cm")),
    plot.caption = element_text( size=12, color = "#4e4d47", margin = margin(b = 0.3, r=-99, unit = "cm") ),

    legend.position = c(0.75, 0.18)
  ) +
  coord_map()
theta
ggsave('mcmc_theta_spatial_map.pdf',device='pdf',width=6,height=6)



# Map of combined spatial effects.
combined_spatial=ggplot() + geom_polygon(data = brasil_map, aes(x=long, y = lat, group = group,fill=combined))+
  theme_void() +
  scale_fill_distiller(palette=col.pal, direction = +1, name=expression(phi[s]+theta[s]),breaks=c(-1,-0.5,0,0.5, 1, 1.5))+#viridis( breaks=c(-0.5,-0.25,0,0.25,0.5), name=expression(phi[s]+theta[s]), guide = guide_legend( keyheight = unit(3, units = "mm"), keywidth=unit(8, units = "mm"), label.position = "bottom", title.position = 'top', nrow=1) ) +
  labs(
    title = "Combined Spatial Effect",
    subtitle = "on Tuberculosis Incidence"
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),

    plot.title = element_text(size= 22, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.43, l = 2, unit = "cm")),
    plot.caption = element_text( size=12, color = "#4e4d47", margin = margin(b = 0.3, r=-99, unit = "cm") ),

    legend.position = c(0.75, 0.18)
  ) +
  coord_map()
combined_spatial
ggsave('mcmc_combined_spatial.pdf',device='pdf',width=6,height=6)

#Map of reporting probabilities.
pi_prob = ggplot() + geom_polygon(data = brasil_map, aes(x=long, y = lat, group = group,fill=pi))+
  theme_void() +
  scale_fill_distiller(palette=col.pal, direction = +1, name=expression('Mean Predicted '*pi[s]), breaks=c(0.5,0.6,0.7,0.8,0.9) ) +#viridis(trans = "logit", breaks=c(0.6,0.7,0.8,0.9), name=expression('Mean Predicted '*pi[s]), guide = guide_legend( keyheight = unit(3, units = "mm"), keywidth=unit(8, units = "mm"), label.position = "bottom", title.position = 'top', nrow=1) ) +
  labs(
    title = "Reporting Probability",
    subtitle = "of Tuberculosis Cases"
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),

    plot.title = element_text(size= 22, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.43, l = 2, unit = "cm")),
    plot.caption = element_text( size=12, color = "#4e4d47", margin = margin(b = 0.3, r=-99, unit = "cm") ),

    legend.position = c(0.75, 0.18)
  ) +
  coord_map()
pi_prob
ggsave('mcmc_pi_map.pdf',device='pdf',width=6,height=6)

# Density plot of proportion of spatial variance explained by phi.
ggplot(data.frame(x=apply(posterior_phi,1,var)/apply(posterior_phi+posterior_theta,1,var)))+
  stat_density(aes(x=x),adjust=2,fill=col.pal.green,alpha=0.4)+
  labs(
    y='Posterior Density',
    x=expression(Var(phi[s])/Var(phi[s]+theta[s]))
  )+
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA)
  )
ggsave('mcmc_phi_var.pdf',device='pdf',width=3,height=2)

# Proportion of spatial variance explained by phi.
round(mean(apply(posterior_phi,1,var)/apply(posterior_phi+posterior_theta,1,var)),2)
round(quantile(apply(posterior_phi,1,var)/apply(posterior_phi+posterior_theta,1,var),c(0.025,0.975)),2)

# Compute covariate effects.
unem_seq=seq(min(TBdata$Unemployment),max(TBdata$Unemployment),length=1000)
urb_seq=seq(min(TBdata$Urbanisation),max(TBdata$Urbanisation),length=1000)
den_seq=seq(min(TBdata$Density),max(TBdata$Density),length=1000)
tim_seq=seq(min(TBdata$Timeliness),max(TBdata$Timeliness),length=1000)
ind_seq=seq(min(tran_ind),max(tran_ind),length=1000)

sorted_unem=TB_mcmc[,2:3]%*%t(predict(poly_unem,unem_seq))
sorted_urb=TB_mcmc[,4:5]%*%t(predict(poly_urb,urb_seq))
sorted_den=TB_mcmc[,6:7]%*%t(predict(poly_den,den_seq))
sorted_ind=TB_mcmc[,8]%*%t(ind_seq)

posterior_tim=expit(TB_mcmc[,9:12]%*%t(cbind(1,poly_tim)))
sorted_tim=expit(TB_mcmc[,9:12]%*%t(cbind(1,predict(poly_tim,tim_seq))))

# Predict covariate effects on TB incidence.
f1=ggplot(data.frame(x=unem_seq,m=apply(sorted_unem,2,mean),
                     l=apply(sorted_unem,2,quantile,0.025),u=apply(sorted_unem,2,quantile,0.975))) +
  geom_ribbon(aes(x=x,ymin=l,ymax=u),fill=col.pal.green,alpha=0.4)+geom_line(aes(x=x,y=m),col=col.pal.green)+
  labs(
    y=expression(f[1](x['s,1'])),
    x=expression('Unemployment ('*x['s,1']*')')
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA)
  )+ scale_y_continuous(limits = c(-1,1.8))
f1
ggsave('mcmc_unemployment.pdf',device='pdf',width=4.5,height=2.5)

f2=ggplot(data.frame(x=urb_seq,m=apply(sorted_urb,2,mean),
                     l=apply(sorted_urb,2,quantile,0.025),u=apply(sorted_urb,2,quantile,0.975))) +
  geom_ribbon(aes(x=x,ymin=l,ymax=u),fill=col.pal.green,alpha=0.4)+geom_line(aes(x=x,y=m),col=col.pal.green)+
  labs(
    y=expression(f[2](x['s,2'])),
    x=expression('Urbanisation ('*x['s,2']*')')
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA)
  )+ scale_y_continuous(limits = c(-1.3,0.9))
f2
ggsave('mcmc_urban.pdf',device='pdf',width=4.5,height=2.5)

f3=ggplot(data.frame(x=den_seq,m=apply(sorted_den,2,mean),
                     l=apply(sorted_den,2,quantile,0.025),u=apply(sorted_den,2,quantile,0.975))) +
  geom_ribbon(aes(x=x,ymin=l,ymax=u),fill=col.pal.green,alpha=0.4)+geom_line(aes(x=x,y=m),col=col.pal.green)+
  labs(
    y=expression(f[3](x['s,3'])),
    x=expression('Dwelling Density ('*x['s,3']*')')
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA)
  )+ scale_y_continuous(limits = c(-1.5,1))
f3
ggsave('mcmc_density.pdf',device='pdf',width=4.5,height=2.5)

f4=ggplot(data.frame(x=ind_seq,m=apply(sorted_ind,2,mean),
                     l=apply(sorted_ind,2,quantile,0.025),u=apply(sorted_ind,2,quantile,0.975))) +
  geom_ribbon(aes(x=x,ymin=l,ymax=u),fill=col.pal.green,alpha=0.4)+geom_line(aes(x=x,y=m),col=col.pal.green)+
  labs(
    y=expression(f[4](x['s,4'])),
    x=expression('Indigenous Proportion ('*x['s,4']*')')
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA)
  )+ scale_y_continuous(limits = c(-1,2.5))
f4
ggsave('mcmc_indigenous.pdf',device='pdf',width=4.5,height=2.5)


# # Predicted timeliness effect.
ggplot(data.frame(x=tim_seq,m=apply(sorted_tim,2,mean),
                  l=apply(sorted_tim,2,quantile,0.025),u=apply(sorted_tim,2,quantile,0.975))) +
  geom_ribbon(aes(x=x,ymin=l,ymax=u),fill=col.pal.green,alpha=0.4)+geom_line(aes(x=x,y=m),col=col.pal.green)+
  labs(
    y=expression('Reporting Probability ('*pi[s]*')'),
    x=expression('Treatment Timeliness ('*u[s]*')')
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA)
  )+ scale_y_continuous(limits = c(0.2,1))
ggsave('mcmc_timeliness.pdf',device='pdf',width=4.5,height=2.5)

# Create bar plot of total TB cases.

bar_data=data.frame( year=as.factor(c('2012','2012','2013','2013','2014','2014')),
                     type=as.factor(c('Observed total count','Predicted true total count','Observed total count','Predicted true total count','Observed total count','Predicted true total count')),
                     value=as.numeric(rbind(total_obs,
                                            apply(posterior_total_y,2,quantile,0.5))))

ggplot(data=bar_data, aes(x=year, y=value, fill=type))+
  geom_col(width = 0.75, position = "dodge",alpha=1) + geom_errorbar(aes(ymin=c(NA, apply(posterior_total_y,2,quantile,0.05)[1],NA, apply(posterior_total_y,2,quantile,0.05)[2],NA, apply(posterior_total_y,2,quantile,0.05)[3]), ymax=c(NA, apply(posterior_total_y,2,quantile,0.95)[1],NA, apply(posterior_total_y,2,quantile,0.95)[2],NA, apply(posterior_total_y,2,quantile,0.95)[3])),
                                                                 size=.5, width=.5, colour = col.pal.green,
                                                                 position=position_dodge(0.75))+labs(

    x='Year',
    y='Total Tuberculosis Cases'
  ) +
  theme(
    text = element_text(color = "#22211d"),
    plot.background = element_rect(fill = "#f5f5f2", color = NA),
    panel.background = element_rect(fill = "#f5f5f2", color = NA),
    legend.background = element_rect(fill = "#f5f5f2", color = NA),

    plot.title = element_text(size= 22, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.4, l = 2, unit = "cm")),
    plot.subtitle = element_text(size= 17, hjust=0.01, color = "#4e4d47", margin = margin(b = -0.1, t = 0.43, l = 2, unit = "cm")),
    plot.caption = element_text( size=12, color = "#4e4d47", margin = margin(b = 0.3, r=-99, unit = "cm") )

  )+scale_fill_manual(values = c(col.pal.seagreen, col.pal.violet)) +theme(legend.title=element_blank())+
  coord_cartesian(ylim = c(0, 120000))
ggsave('mcmc_bar.pdf',device='pdf',width=4.5,height=2.5)

print(Sys.time())
