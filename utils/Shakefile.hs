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
    
    -- Discover all base page files to determine what pagefull files should exist
    phony "all" $ do
        -- Find all base page files
        basePages <- getDirectoryFiles "." ["page*.png"]
        
        -- Extract the numbers using regex
        let basePattern = "page([0-9]+)\\.png$" :: String
        let pageNumbers = [num | page <- basePages,
                           let (_, _, _, groups) = page =~ basePattern :: (String, String, String, [String]),
                           num <- take 1 groups]
        
        -- Create targets for all pagefull files corresponding to base pages
        let targets = ["pagefull" ++ num ++ ".png" | num <- pageNumbers]
        
        -- Print discovered targets
        liftIO $ putStrLn $ "Building targets: " ++ unwords targets
        
        -- Need these targets
        need targets
        need ["index.org"]
    
    -- Default to building all
    want ["all"]
    
    -- Rule for building pagefull{N}.png files
    "pagefull*.png" %> \out -> do
        -- Extract the number from the output filename
        let (_, _, _, groups) = out =~ pagefullPattern :: (String, String, String, [String])
        case groups of
            (num:_) -> do
                -- Define the base dependency
                let basePage = "page" ++ num ++ ".png"
                
                -- Check if the base page exists
                baseExists <- doesFileExist basePage
                
                -- If base doesn't exist, fail the build
                unless baseExists $ 
                    error $ "Base page file " ++ basePage ++ " does not exist"
                
                -- Always check for _2 and _3 variants, even if they didn't exist before
                let variant2 = "page" ++ num ++ "_2.png"
                let variant3 = "page" ++ num ++ "_3.png"
                
                variant2Exists <- doesFileExist variant2
                variant3Exists <- doesFileExist variant3
                
                -- Build the dependencies list based on what exists
                let deps = [basePage] 
                         ++ [variant2 | variant2Exists]
                         ++ [variant3 | variant3Exists]
                
                -- Print the command before executing it
                let cmdArgs = ["magick"] ++ deps ++ ["-layers", "flatten", out]
                liftIO $ putStrLn $ "Executing command: " ++ unwords cmdArgs
                
                -- Declare dependencies - this ensures rebuilding if any source file changes
                need deps
                
                -- Command to build the pagefull file
                cmd_ "magick" deps "-layers" "flatten" out
            _ -> error $ "Could not extract number from " ++ out

    "index.org" %> \out -> do
        -- TODO: necesita dos pasadas, en la primera crea el header pero no los headings
        -- Find all full page files
        fullPages <- getDirectoryFiles "." ["pagefull*.png"]
        need fullPages


        -- Extract the numbers using regex
        let basePattern = "pagefull([0-9]+)\\.png$" :: String
        let pageNumbers = [num | page <- fullPages,
                           let (_, _, _, groups) = page =~ basePattern :: (String, String, String, [String]),
                           num <- take 1 groups]
        -- Create targets for all pagefull files corresponding to base pages
        let targets = ["pagefull" ++ num ++ ".png" | num <- pageNumbers]

        let header = "#+STARTUP: inlineimages\n#+FILETAGS: :private:\n" :: String
        let heading = ["* pagefull" ++ num ++ ".png\n:PROPERTIES:\n:ROAM_EXCLUDE: t\n:END:\n#+ATTR_ORG: :width 430\n[[file:" ++ "pagefull" ++ num ++ ".png]]" | num <- pageNumbers]
        let allContents = header ++ unlines heading
        writeFile' out allContents
    
    -- Phony rule to rebuild everything
    phony "clean" $ do
        putNormal "Cleaning files"
        removeFilesAfter "." ["pagefull*.png"]
        removeFilesAfter "." ["index.org"]

