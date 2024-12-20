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

inSim <- SpaDES.project::setupProject(
  useGit=  FALSE, #"eliotmcintire",
  paths = list(projectPath = "~/GitHub/NEBC",
               cachePath = "cache",
               outputPath = file.path("outputs", currentName)
  ),
  modules = "PredictiveEcology/Biomass_borealDataPrep@development",
  options = options(gargle_oauth_email = "predictiveecology@gmail.com",
                    spades.allowInitDuringSimInit = TRUE,
                    spades.moduleCodeChecks = FALSE,
                    spades.useRequire = FALSE,
                    reproducible.inputPaths = "~/data",
                    Require.cloneFrom = Sys.getenv("R_LIBS_USER"),
                    # 'reproducible.gdalwarp' = TRUE,
                    reproducible.cacheSaveFormat = "qs",
                    reproducible.useMemoise = TRUE,
                    reproducible.showSimilar = TRUE,
                    reproducible.showSimilarDepth = 6
  ),
  packages = c("pkgload", "box", "httr2", "igraph"),
  require = "reproducible",
  functions = "ianmseddy/NEBC@main/R/studyAreaFuns.R",
  sa = setupSAandRTM(ecoprovinceNum = ecoprovince) |> Cache(),
  studyArea = sa$studyArea,
  studyAreaLarge = sa$studyArea,
  rasterToMatch = sa$rasterToMatch,
  rasterToMatchLarge = sa$rasterToMatch

)
pkgload::load_all("~/GitHub/reproducible/");
pkgload::load_all("~/GitHub/SpaDES.core/");
outSim <- do.call(what = SpaDES.core::simInitAndSpades, args = inSim)

