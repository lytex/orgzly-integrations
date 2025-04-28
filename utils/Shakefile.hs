#!/usr/bin/env runhaskell
{-# LANGUAGE RecordWildCards #-}

import Development.Shake
import Development.Shake.FilePath
import Control.Monad
import Data.List
import Text.Regex.TDFA

main :: IO ()
main = shakeArgs shakeOptions $ do
    -- Define the pattern for pagefull files
    let pagefullPattern = "pagefull([0-9]+)\\.png$" :: String
    
    -- Use a phony target to discover and build all pagefull files
    phony "all" $ do
        files <- getDirectoryFiles "." ["pagefull*.png"]
        need files
    
    -- Default to building all
    want ["all"]
    
    -- Rule for building pagefull{N}.png files
    "pagefull*.png" %> \out -> do
        -- Extract the number from the output filename
        let (_, _, _, groups) = out =~ pagefullPattern :: (String, String, String, [String])
        case groups of
            (num:_) -> do
                -- Define the dependencies with proper file extensions
                let basePage = "page" ++ num ++ ".png"
                let deps = [basePage]
                
                -- Check if the _2 and _3 variants exist
                pageVariant2 <- doesFileExist ("page" ++ num ++ "_2.png")
                pageVariant3 <- doesFileExist ("page" ++ num ++ "_3.png")
                
                -- Add existing variants to dependencies
                let deps' = deps ++ ["page" ++ num ++ "_2.png" | pageVariant2] 
                                 ++ ["page" ++ num ++ "_3.png" | pageVariant3]
                
                -- Print the command before executing it
                let cmdArgs = ["magick"] ++ deps' ++ ["-layers", "flatten", out]
                liftIO $ putStrLn $ "Executing command: " ++ unwords cmdArgs
                
                -- Declare dependencies
                need deps'
                
                -- Command to build the pagefull file using magick with -layers flatten
                cmd_ "magick" deps' "-layers" "flatten" out
            _ -> error $ "Could not extract number from " ++ out
    
    -- Phony rule to rebuild everything
    phony "clean" $ do
        putNormal "Cleaning files"
        removeFilesAfter "." ["pagefull*.png"]
