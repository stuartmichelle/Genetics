# This script evaluates the output of a cervus identity analysis and flags "true matches" versus "false positives"
# TODO - make a list of good matches and a list of bad matches and see where they intersect, then drop bad part of the bad match sample but not the good part.


# Set up workspace --------------------------------------------------------

source("code/readGenepop_space.R")

# Import cervus identity results ------------------------------------------
  idcsv <- read.csv("data/809_seq17-03_ID.csv", stringsAsFactors = F)

# # # if necessary, strip IDs down to ligation id only
# for (i in 1:nrow(idcsv)){
#   if(nchar(idcsv$First.ID[i]) == 15){
#     idcsv$First.ID[i] <- paste("APCL_", substr(idcsv$First.ID[i], 11, 15), sep = "")
#   }
#   if(nchar(idcsv$First.ID[i]) == 10){
#     idcsv$First.ID[i] <- substr(idcsv$First.ID[i], 6, 10)
#   }
# }
# for (i in 1:nrow(idcsv)){
#   if(nchar(idcsv$Second.ID[i]) == 15){
#     idcsv$Second.ID[i] <- paste("APCL_", substr(idcsv$Second.ID[i], 11, 15), sep = "")
#   }
#   if(nchar(idcsv$Second.ID[i]) == 10){
#     idcsv$Second.ID[i] <- substr(idcsv$Second.ID[i], 6, 10)
#   }
# }

# Add metadata ------------------------------------------------------------

# Connect to database -----------------------------------------------------

suppressMessages(library(dplyr))
labor <- src_mysql(dbname = "Laboratory", default.file = path.expand("~/myconfig.cnf"), port = 3306, create = F, host = NULL, user = NULL, password = NULL)

# add Sample IDs
suppressWarnings(c1 <- labor %>% tbl("extraction") %>% select(extraction_id, sample_id))
suppressWarnings(c2 <- labor %>% tbl("digest") %>% select(digest_id, extraction_id))
c3 <- left_join(c2, c1, by = "extraction_id")
suppressWarnings(c4 <- labor %>% tbl("ligation") %>% select(ligation_id, digest_id))
c5 <- left_join(c4, c3, by = "digest_id") %>% collect()

### WAIT ###

# for First.ids 
lab1 <- c5
names(lab1) <- paste("First.", names(lab1), sep = "")

idcsv <- left_join(idcsv, lab1, by = c("First.ID" = "First.ligation_id"))

### WAIT ###

# For Second.IDs
lab2 <- c5
names(lab2) <- paste("Second.", names(lab2), sep = "")

idcsv <- left_join(idcsv, lab2, by = c("Second.ID" = "Second.ligation_id"))


# check proportion of matches/mismatches
idcsv <- idcsv %>% mutate(mismatch_prop = Mismatching.loci/(Mismatching.loci+Matching.loci))

plot(mismatch_prop ~ Matching.loci, idcsv, bty = "n", las = 1, xlim = c(600,1100), ylim = c(0,0.15))
# bty "l" is this type, "n" is no box
#las 1 is all labels horizontal, 2 is always perpendicular to axis, 3 is always vertical.

# clean up
rm(lab1, lab2, c1, c2, c3, c4, c5, i)

# Add field data ----------------------------------------------------------
leyte <- src_mysql(dbname = "Leyte", default.file = path.expand("~/myconfig.cnf"), port = 3306, create = F, host = NULL, user = NULL, password = NULL)

suppressWarnings(c1 <- leyte %>% tbl("diveinfo") %>% select(id, date, name))
suppressWarnings(c2 <- leyte %>% tbl("anemones") %>% select(dive_table_id, anem_table_id, ObsTime))
c3 <- left_join(c2, c1, by = c("dive_table_id" = "id"))
suppressWarnings(c4 <- tbl(leyte, sql("SELECT fish_table_id, anem_table_id, sample_id, Size FROM clownfish where sample_id is not NULL")))
first <- left_join(c4, c3, by = "anem_table_id") %>% collect()

### WAIT ###

second <- first

names(first) <- paste("First.", names(first), sep = "")
names(second) <- paste("Second.", names(second), sep = "")
idcsv <- left_join(idcsv, first, by = c("First.sample_id" = "First.sample_id"))
idcsv <- left_join(idcsv, second, by = c("Second.sample_id" = "Second.sample_id"))

rm(first, second, labor, c1, c2, c3, c4)

idcsv$First.lat <- NA
idcsv$First.lon <- NA
idcsv$Second.lat <- NA
idcsv$Second.lon <- NA

latlong <- leyte %>% tbl("GPX") %>% collect()

### WAIT ###

# Add lat long for first.id -----------------------------------------------
for(i in 1:nrow(idcsv)){
  #Get date and time information for the anemone
  date <- as.character(idcsv$First.date[i])
  datesplit <- strsplit(date,"-", fixed = T)[[1]]
  year <- as.numeric(datesplit[1])
  month <- as.numeric(datesplit[2])
  day <- as.numeric(datesplit[3])
  time <- as.character(idcsv$First.ObsTime[i])
  timesplit <- strsplit(time, ":", fixed = T)[[1]]
  hour <- as.numeric(timesplit[1])
  min <- as.numeric(timesplit[2])
  sec <- as.numeric(timesplit[3])
  
  # Convert time to GMT
  hour <- hour - 8
  if(!is.na(hour) & hour < 0){
    day <- day - 1
    hour <- hour + 24
  }

  # Find the location records that match the date/time stamp (to nearest second)
  latlongindex <- which(latlong$year == year & latlong$month == month & latlong$day == day & latlong$hour == hour & latlong$min == min)
  i2 <- which.min(abs(latlong$sec[latlongindex] - sec))
  
  # Calculate the lat/long for this time
  if(length(i2)>0){
    idcsv$First.lat[i] = latlong$lat[latlongindex][i2]
    idcsv$First.lon[i] = latlong$long[latlongindex][i2]
  }
}

### WAIT ###

# Add lat long for second.id ----------------------------------------------
for(i in 1:nrow(idcsv)){
  #Get date and time information for the anemone
  date <- as.character(idcsv$Second.date[i])
  datesplit <- strsplit(date,"-", fixed = T)[[1]]
  year <- as.numeric(datesplit[1])
  month <- as.numeric(datesplit[2])
  day <- as.numeric(datesplit[3])
  time <- as.character(idcsv$Second.ObsTime[i])
  timesplit <- strsplit(time, ":", fixed = T)[[1]]
  hour <- as.numeric(timesplit[1])
  min <- as.numeric(timesplit[2])
  sec <- as.numeric(timesplit[3])
  
  # Convert time to GMT
  hour <- hour - 8
  if(!is.na(hour) & hour <0){
    day <- day-1
    hour <- hour + 24
  }
  
  # Find the location records that match the date/time stamp (to nearest second)
  latlongindex <- which(latlong$year == year & latlong$month == month & latlong$day == day & latlong$hour == hour & latlong$min == min)
  i2 <- which.min(abs(latlong$sec[latlongindex] - sec))
  
  # Calculate the lat/long for this time
  if(length(i2)>0){
    idcsv$Second.lat[i] = latlong$lat[latlongindex][i2]
    idcsv$Second.lon[i] = latlong$long[latlongindex][i2]
  }
}

### WAIT ###

# cleanup
rm(date, datesplit, day, hour , i , i2, latlongindex, min, month, sec, time, timesplit, year, latlong)

# Flag matches with same date of capture ----------------------------------
# idcsv$First.date <- as.Date(idcsv$First.date, "%m/%d/%Y")
# idcsv$Second.date <- as.Date(idcsv$Second.date, "%m/%d/%Y")


idcsv$date_eval <- NA
for(i in 1:nrow(idcsv)){
  a <- idcsv$First.date[i]
  b <- idcsv$Second.date[i]
  if (a == b & !is.na(a) & !is.na(b)){
    idcsv$date_eval[i] <- "FAIL"
  }
}

### WAIT ### - if you have to wait here, double check the number of obs, there may be a problem with the attachment of metadata

# Flag matches that were caught more than 250m apart ----------------------


# library(fields)
# source('greatcircle_funcs.R') # alternative, probably faster
alldists <- fields::rdist.earth(as.matrix(idcsv[,c('First.lon', 'First.lat')]), as.matrix(idcsv[,c('Second.lon', 'Second.lat')]), miles=FALSE, R=6371) # see http://www.r-bloggers.com/great-circle-distance-calculations-in-r/ # slow because it does ALL pairwise distances, instead of just in order
idcsv$distkm <- diag(alldists)

idcsv$disteval <- NA # placeholder
for(i in 1:nrow(idcsv)){
  if(!is.na(idcsv$distkm[i]) & 0.250 <= idcsv$distkm[i]){
    idcsv$disteval[i] <- "FAIL"
  }
}


# Flag idcsves where size decreases by more than 1.5cm --------------------

idcsv$size_eval <- NA
for (i in 1:nrow(idcsv)){
  if(!is.na(idcsv$First.date[i]) & !is.na(idcsv$Second.date[i])  & idcsv$First.date[i] < idcsv$Second.date[i]) {
    if(!is.na(idcsv$First.Size[i]) & !is.na(idcsv$Second.Size[i]) & (idcsv$First.Size[i] - 1.5) > idcsv$Second.Size[i]){
      idcsv$size_eval[i] <- "FAIL"
    }
  }
}
  
for (i in 1:nrow(idcsv)){
  if(!is.na(idcsv$First.date[i]) & !is.na(idcsv$Second.date[i])  & idcsv$First.date[i] > idcsv$Second.date[i]) {
    if(!is.na(idcsv$First.Size[i]) & (idcsv$First.Size[i] + 1.5) < idcsv$Second.Size[i]){
      idcsv$size_eval[i] <- "FAIL"
    }
  }
}


# Write output ------------------------------------------------------------

write.csv(idcsv, file = paste("data/", Sys.Date(), "_idanalyis.csv", sep = ""), row.names = F)

# cleanup
# rm(alldists, c5, first, lab1, lab2, latlong, second, a, b, c1, c2, c3, c4, date, datesplit, day, hour, i, i2, latlongindex, min, month, sec, time, timesplit, year)

### EVERYTHING AFTER THIS POINT IS FOR REMOVING THE MATCHES FROM THE GENEPOP
# SO IT CAN CONTINUE FOR PARENTAGE ANALYSIS.  FOR CONTINUED ID ANALYSIS, OPEN id_process.R ###

# Open genepop ------------------------------------------------------------

genfile <- "data/2016-12-20_noregeno.gen" # this should be the genepop you used as input for Cervus ID
genedf <- readGenepop(genfile)

### WAIT ###

genedf$pop <- NULL # remove the pop column from the data file
# TEST - make sure the first 2 columns are names and a contig and get number of rows
names(genedf[,1:2]) # [1] "names" "dDocent_Contig_107_30"
nrow(genedf) # 1824


# Calculate the number of loci for analysis -------------------------------

# convert 0000 to NA in the genepop data
genedf[genedf == "0000"] = NA
# TEST - make sure there are no "0000" left
which(genedf == "0000") # should return integer(0)

# count the number of loci per individual
for(h in 1:nrow(genedf)){
  genedf$numloci[h] <- sum(!is.na(genedf[h,]))
}

### WAIT ###

# TEST - make sure all of the numloci were populated
which(is.na(genedf$numloci)) # should return integer(0)

genedf$drop <- NA

# Run through id analysis and compare to determine which to remove --------
for(i in 1:nrow(idcsv)){
  # a & b are  the line numbers from genepop file that matches an the first and second ID in the match table
  a <- which(genedf$names == idcsv$First.ID[i])
  b <- which(genedf$names == idcsv$Second.ID[i])
if (genedf$numloci[a] > genedf$numloci[b]){
  genedf$drop[b] <- "DROP"
} else{
  genedf$drop[a] <- "DROP"
}
}

# Make a dataframe of the samples that will be dropped
drops <- genedf[!is.na(genedf$drop),]

# Make a dataframe of the samples to keep for parentage analysis
keep <- genedf[is.na(genedf$drop),]

keep$numloci <- NULL
keep$drop <- NULL

# TODO -  Look for regenotypes again:

# convert all the NA genotypes to 0000
keep[is.na(keep)] = "0000"
# TEST - make sure there are no NA's left
which(is.na(keep)) # should return integer(0)

# Write out genepop  ------------------------------------------------------

# Build the genepop components
msg <- c("This genepop file was generated using a script called identity_analysis.R written by Michelle Stuart with help from Malin Pinsky and Ryan Batt")

loci <- paste(names(keep[,2:ncol(keep)]), collapse =",")

gene <- vector()
sample <- vector()
for (i in 1:nrow(keep)){
  gene[i] <- paste(keep[i,2:ncol(keep)], collapse = " ")
  sample[i] <- paste(keep[i,1], gene[i], sep = ", ")
}

  ### WAIT ###

out <- c(msg, loci, 'pop', sample)

write.table(out, file = paste("data/",Sys.Date(), "_norecap.gen", sep = ""), row.names=FALSE, quote=FALSE, col.names=FALSE)


