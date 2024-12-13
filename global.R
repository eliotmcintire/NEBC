# Install or update SpaDES.project & Require
source("https://raw.githubusercontent.com/PredictiveEcology/pemisc/refs/heads/development/R/getOrUpdatePkg.R")
getOrUpdatePkg(c("Require", "SpaDES.project"), c("1.0.1.9002", "0.1.1.9004")) # only install/update if required

currentName <- "Taiga" #toggle between Skeena and Taiga
if (currentName == "Taiga") {
  ecoprovince <- c("4.3")
  studyAreaPSPprov <- c("4.3", "12.3", "14.1", "9.1") #this is a weird combination
  snll_thresh = 3100 # 4822 after running the estimator
} else {
  ecoprovince <- "14.1"
  studyAreaPSPprov <- c("14.1", "14.2", "14.3", "14.4")
  snll_thresh = 1200
}

# if (!Sys.info()[["nodename"]] == "W-VIC-A127551") {
#   #this must be run in advance at some point -
#   # I don't know how to control the token expiry - gargle documentation is crappy
#   # mytoken <- gargle::gargle2.0_token(email = "ianmseddy@gmail.com")
#   # saveRDS(mytoken, "googlemagic.rds")
#   googledrive::drive_auth(email = "ianmseddy@gmail.com",
#                           token = readRDS("googlemagic.rds"))
# }

#TODO change the script so that ecoprovinceNum is consistently named in functinos
inSim <- SpaDES.project::setupProject(
  useGit=  FALSE, #"eliotmcintire",
  paths = list(projectPath = "~/GitHub/NEBC",
               cachePath = "cache",
               outputPath = file.path("outputs", currentName)
  ),
  modules = c("PredictiveEcology/fireSense_dataPrepFit@lccFix",
              "PredictiveEcology/Biomass_borealDataPrep@development",
              "PredictiveEcology/Biomass_speciesData@development",
              "PredictiveEcology/fireSense_SpreadFit@lccFix",
              "PredictiveEcology/fireSense_IgnitionFit@biomassFuel",
              "PredictiveEcology/canClimateData@improveCache1"
  ),
  require = c("reproducible"), # for Cache
  options = options(gargle_oauth_email = "predictiveecology@gmail.com",
                    spades.allowInitDuringSimInit = TRUE,
                    spades.moduleCodeChecks = FALSE,
                    Require.cloneFrom = Sys.getenv("R_LIBS_USER"),
                    # 'reproducible.gdalwarp' = TRUE,
                    reproducible.cacheSaveFormat = "qs",
                    reproducible.useMemoise = TRUE,
                    SpaDES.project.fast = FALSE,
                    reproducible.shapefileRead = "terra::vect",
                    spades.recoveryMode = 1,
                    reproducible.useDBI = FALSE,
                    reproducible.overwrite = TRUE,
                    reproducible.inputPaths = "~/data",
                    # reproducible.useCache = "devMode",
                    reproducible.cloudFolderID = "1oNGYVAV3goXfSzD1dziotKGCdO8P_iV9",
                    reproducible.showSimilar = TRUE,
                    reproducible.showSimilarDepth = 6,

                    # Eliot during development
                    fireSenseUtils.runTests = FALSE,
                    reproducible.memoisePersist = TRUE # sets the memoise location to .GlobalEnv; persists through a `load_all`


  ),
  times = list(start = 2011, end = 2021),
  functions = "ianmseddy/NEBC@main/R/studyAreaFuns.R",
  climateVariablesForFire = list(ignition = "CMDsm",
                                 spread = "CMDsm"),
  sppEquiv = {
    makeSppEquiv(ecoprovinceNum = ecoprovince) |> Cache()
    },
  #update mutuallyExlcusive Cols
  sa = setupSAandRTM(ecoprovinceNum = ecoprovince) |> Cache(),
  studyArea = sa$studyArea,
  rasterToMatch = sa$rasterToMatch,
  rasterToMatchLarge = sa$rasterToMatch,
  studyAreaLarge = sa$studyArea,
  studyAreaReporting = sa$studyAreaReporting,
  rasterToMatchReporting = sa$rasterToMatchReporting,
  studyAreaPSP = {setupSAandRTM(ecoprovinceNum = studyAreaPSPprov)$studyArea |>
        terra::aggregate() |>
        terra::buffer(width = 10000)} |> Cache(),
  nonForestedLCCGroups = list(
    "nf_dryland" = c(50, 100, 40), # shrub, herbaceous, bryoid
    "nf_wetland" = c(81)), #non-treed wetland.
  fireSense_ignitionFormula = paste0("ignitionsNoGT1 ~ (1|yearChar) + youngAge:CMDsm + nf_wetland:CMDsm",
                                     " + nf_dryland:CMDsm + ", paste0(unique(sppEquiv$fuel), ":CMDsm",
                                                                      collapse = " + ")),
  cores = {
    # c(paste0("bc", c("97", "106", "184", "189", "213", "217", "220")),
    #   "localhost",
    #   paste0("n", c("14", "105")))
    c(rep("bc213", 7),
      rep("localhost", 16),
      rep("n105", 13),
      rep("n14", 16),
      rep("bc184", 14),
      rep("bc217", 12),
      rep("n68", 20)
    )
  },
  #params last because one of them depends on sppEquiv fuel class names

  climateVariables = list(
    historical_CMDsm = list(
      vars = "historical_CMD_sm",
      fun = quote(calcAsIs),
      .dots = list(historical_years = 1991:2022)
    )
  ),
  params = list(
    .globals = list(.studyAreaName = currentName,
                    dataYear = 2011,
                    .plots = "png",
                    sppEquivCol = "LandR",
                    .useCache = c(".inputObjects", "init")),
    Biomass_borealDataPrep = list(
      overrideAgeInFires = FALSE,
      overrideBiomassInFires = FALSE
    ),
    canClimateData = list(
      projectedClimateYears = 2011:2061,
      .useCloud = FALSE
    ),
    fireSense_SpreadFit = list(
      mutuallyExclusiveCols = list({
        youngAge = c("nf", unique(makeSppEquiv(ecoprovinceNum = ecoprovince)$fuel))
      }
      ),
      .useCache = FALSE,
      iterStep = 250, # run this many iterations before running again; this should be
                      # set to itermax if Cache is not used; it is only useful for Cache
      cores = "localhost",
        #  "spades217",
        #"spades184")#, "spades213")
        #hosts <-
        #paste0("spades", c("97", "106", "184", "189", "213", "217", "220")))
        #c(hosts, "132.156.148.105", "localhost")
      NP = {if (identical(cores, unique(cores))) 100 else length(cores)}, # number of cores of machines
        # pemisc::makeIpsForNetworkCluster(
        # ipStart = "10.20.0",
        # ipEnd = c(97, 184, 189, 213, 220, 217, 106),
        # availableCores = c(28, 28, 28, 14, 14),
        # availableRAM = c(500, 500, 500, 250, 250),
        # localHostEndIp = 189,
        # proc = "cores",
        # nProcess = 10,
        # internalProcesses = 10,
        # sizeGbEachProcess = 1),
      trace = 1,
      # mode = c("fit", "visualize"),
      mode = c("debug"),
      # SNLL_FS_thresh = snll_thresh,
      doObjFunAssertions = FALSE
    ),
    fireSense_dataPrepFit = list(
      spreadFuelClassCol = "fuel",
      ignitionFuelClassCol = "fuel",
      missingLCCgroup = c("nf_dryland"),
      .useCache = c(".inputObjects", "init", "prepSpreadFitData")
    ),
    fireSense_IgnitionFit = list(
      rescalers = c("CMDsm" = 1000),
      .useCache = c(".inputObjects", "init", "prepIgnitionFitData")
    )
  )
)

#add this after because of the quoted functions
# inSim$climateVariables <- list(
#   historical_CMDsm = list(
#     vars = "historical_CMD_sm",
#     fun = quote(calcAsIs),
#     .dots = list(historical_years = 1991:2022)
#   )
# )


#known bugs/undesirable behavior
#1 spreadFit dumps a bunch of figs in the project directory instead of outputs
#2 canClimateData occasionally fails, rather mysteriously. Unclear why
#3 Google Auth can be irritating when running via Bash

# devtools::install("~/GitHub/reproducible/", upgrade = FALSE); devtools::install("~/GitHub/SpaDES.core/", upgrade = FALSE);
# devtools::install("~/GitHub/climateData/", upgrade = FALSE);
# devtools::install("~/GitHub/fireSenseUtils/", upgrade = FALSE);
# devtools::install("~/GitHub/clusters/", upgrade = FALSE);
#
# pkgload::load_all("~/GitHub/reproducible/");
# pkgload::load_all("~/GitHub/SpaDES.core/");
# pkgload::load_all("~/GitHub/climateData/");
# pkgload::load_all("~/GitHub/fireSenseUtils/");
# pkgload::load_all("~/GitHub/clusters/");
# devtools::document("~/GitHub/fireSenseUtils/");
# clearCache(ask = F)
outSim <- do.call(what = SpaDES.core::simInitAndSpades, args = inSim)


if (FALSE) {
  pkgload::load_all("~/GitHub/fireSenseUtils/");
  pkgload::load_all("~/GitHub/clusters/");
  SpaDES.core::restartSpades()
}
