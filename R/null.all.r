null.all<-function(population)
{
  # Confirm that the function has been provided with a genind object
  if (class(population) != "genind"){
    message("You did not provide a valid genind object! Script stopped!")
    return
  }
  
  # divide the genind object into individual loci
  split<-seploc(population)
  ninds<-dim(population@tab)[1]
  maxalleles<-max(population@loc.n.all)
  
  per.results<-matrix(NA,nrow=length(split),ncol=maxalleles)
  list.obs.ho.cnt<-list()
  list.exp.ho<-list()
  
  # for each locus...
  for(i in 1:length(split)){
    # for each allele, count the number of that type seen
    allelecnt<-apply(split[[i]]@tab,2,sum,na.rm=TRUE)
    
    # get the number of observed homozygotes for each allele
    obs_ho<-alply(split[[i]]@tab,2,table)
    obs_ho_cnt<-rep(NA,length(obs_ho))
    for (j in 1:length(obs_ho)){
      find1s<-which(names(obs_ho[[j]])=="2") # if this was changed to ploidy, could be generic...
      if(length(find1s)==0) {
        obs_ho_cnt[j]<-0
      } else {
        obs_ho_cnt[j]<-unname(obs_ho[[j]][find1s])
      }
    }
    
    # calculate the allele frequencies
    allelefreq<-allelecnt/sum(allelecnt)
    
    # get the expected counts of homozygotes for each allele
    numho<-matrix(NA,nrow=1000,ncol=length(allelefreq))
    for (k in 1:999){ # this is looping over replicates....
      tempgenotype<-matrix(sample(1:length(allelecnt),sum(allelecnt),replace=TRUE,prob=allelefreq),ncol=2)# generating sets of genotypes
      allelepairtab<-table(tempgenotype[,1],tempgenotype[,2])
      allelepairlong<-melt(allelepairtab)
      for(l in 1:length(allelecnt)){
        left<-which(allelepairlong[,1]==l)
        right<-which(allelepairlong[,2]==l)
        matching<-intersect(left,right)
        if (length(matching)==0) {
          numho[k,l]<-0
        } else {
          numho[k,l]<-allelepairlong[matching,3]
        }      
      }
    }
    numho[1000,]<-obs_ho_cnt
    per.results[i,1:length(obs_ho_cnt)]<-sapply(1:dim(numho)[2],function(x,obs_ho_cnt,numho) sum(numho[,x]>obs_ho_cnt[x])/1000, obs_ho_cnt,numho)
    list.obs.ho.cnt[[i]]<-obs_ho_cnt
    list.exp.ho[[i]]<-numho
  }
  rownames(per.results)<-unname(locNames(population))
  suffix<-seq(1:maxalleles)
  colnames(per.results)<-paste("Allele-",suffix,sep="")
  
  homozygotes<-list(observed=list.obs.ho.cnt,bootstrap=list.exp.ho,probability.obs=per.results)
  
  
  # calculate null allele frequencies...
  
  distr1<-matrix(NA,nrow=1000,ncol=length(split))
  distr2<-matrix(NA,nrow=1000,ncol=length(split))
  morethan1<-unname(population@loc.n.all)>1
  for(k in 1:length(morethan1)){
    if (!morethan1[k]) warning("Locus ",unname(locNames(population)[k])," has only 1 allele and null allele frequency will not be estimated for it")
  }
  for (i in 1:999){
    for (j in 1:length(split)){
      if (morethan1[j]){
        tempalleles<-split[[j]]@tab[sample(1:ninds,ninds,replace=TRUE),]  # this is randomly drawing individuals from the population that have been sampled
        allelecnt<-apply(tempalleles,2,sum,na.rm=TRUE) # counting the number of each allele type
        allelefreq<-allelecnt/sum(allelecnt)
        exphz<-1-sum(allelefreq^2)
        ho_cnt<-melt(table(tempalleles))
        numhz<-ninds-ho_cnt$value[ho_cnt$temp==2]
        numho<-ho_cnt$value[ho_cnt$temp==2]
        obshz<-1-numho/(numho+numhz)
        distr1[i,j]<-(exphz-obshz)/(exphz+obshz)
        distr2[i,j]<-(exphz-obshz)/(1+obshz)  
      }
    }
  }
  for (k in 1:length(split)){
    if(morethan1[k]){
      tempalleles<-split[[k]]@tab
      allelecnt<-apply(tempalleles,2,sum,na.rm=TRUE)
      allelefreq<-allelecnt/sum(allelecnt)
      exphz<-1-sum(allelefreq^2)
      ho_cnt<-melt(table(tempalleles))
      numhz<-ninds-ho_cnt$value[ho_cnt$tempalleles==2]
      numho<-ho_cnt$value[ho_cnt$tempalleles==2]  # this is where I need to start tomorrow
      obshz<-1-numho/(numho+numhz)
      distr1[1000,k]<-(exphz-obshz)/(exphz+obshz)
      distr2[1000,k]<-(exphz-obshz)/(1+obshz)  
    }
  }
  
  null.allele.boot.dist<-list(method1=distr1,method2=distr2)
  
  method1<-matrix(NA,nrow=4,ncol=length(split))
  method2<-matrix(NA,nrow=4,ncol=length(split))
  
  method1[1,]<-distr1[1000,]
  method2[1,]<-distr2[1000,]
  
  method1[2,]<-apply(distr1,2,median,na.rm=TRUE)
  method2[2,]<-apply(distr2,2,median,na.rm=TRUE)
  
  method1[3,]<-apply(distr1,2,quantile,0.025,na.rm=TRUE)
  method1[4,]<-apply(distr1,2,quantile,0.975,na.rm=TRUE)
  method2[3,]<-apply(distr2,2,quantile,0.025,na.rm=TRUE)
  method2[4,]<-apply(distr2,2,quantile,0.975,na.rm=TRUE)
  
  rownames(method1)<-c("Observed frequency","Median frequency","2.5th percentile","97.5th percentile")
  rownames(method2)<-c("Observed frequency","Median frequency","2.5th percentile","97.5th percentile")
  colnames(method1)<-unname(locNames(population))
  colnames(method2)<-unname(locNames(population))
  
  null.allele.freq<-list(summary1=method1,summary2=method2,bootstrap=null.allele.boot.dist)
  results.null.alleles<-list(homozygotes=homozygotes,null.allele.freq=null.allele.freq)
  return(results.null.alleles)
}