#!/usr/bin/env runhaskell
{-# LANGUAGE RecordWildCards #-}

import Development.Shake
import Development.Shake.FilePath
import Control.Monad
import Data.List
import Text.Regex.TDFA
import Text.Printf
import qualified System.Directory as Dir
import Data.Time
import Control.Exception (try, IOException)

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
        need ["index.html"]
        need ["sync-files"]
    
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
        -- Find all base page files (same logic as in "all" rule)
        basePages <- getDirectoryFiles "." ["page*.png"]
        
        -- Extract the numbers using regex
        let basePattern = "page([0-9]+)\\.png$" :: String
        let pageNumbers = [num | page <- basePages,
                           let (_, _, _, groups) = page =~ basePattern :: (String, String, String, [String]),
                           num <- take 1 groups]
        
        -- Create targets for all pagefull files corresponding to base pages
        let targets = ["pagefull" ++ num ++ ".png" | num <- pageNumbers]
        
        -- Declare dependency on the pagefull files
        need targets

        let header = "#+STARTUP: inlineimages\n#+FILETAGS: :private:\n" :: String
        let heading = ["* pagefull" ++ num ++ ".png\n:PROPERTIES:\n:ROAM_EXCLUDE: t\n:END:\n#+ATTR_ORG: :width 430\n[[file:" ++ "pagefull" ++ num ++ ".png]]" | num <- pageNumbers]
        let allContents = header ++ unlines heading
        writeFile' out allContents

    -- Bidirectional sync rule
    phony "sync-files" $ do
        orgExists <- liftIO $ Dir.doesFileExist "index.org"
        htmlExists <- liftIO $ Dir.doesFileExist "index.html"
        
        case (orgExists, htmlExists) of
            (False, False) -> return () -- Nothing to sync
            (True, False) -> do
                -- Only org exists, create HTML
                putNormal "Creating index.html from index.org"
                need ["index.html"]
            (False, True) -> do
                -- Only HTML exists, create org
                putNormal "Creating index.org from index.html"
                need ["index.org.from-html"]
            (True, True) -> do
                -- Both exist, sync based on modification time
                orgTimeResult <- liftIO $ (try :: IO UTCTime -> IO (Either IOException UTCTime)) (Dir.getModificationTime "index.org")
                htmlTimeResult <- liftIO $ (try :: IO UTCTime -> IO (Either IOException UTCTime)) (Dir.getModificationTime "index.html")
                
                case (orgTimeResult, htmlTimeResult) of
                    (Right orgTime, Right htmlTime) -> do
                        if orgTime > htmlTime
                        then do
                            putNormal "index.org is newer, updating index.html"
                            need ["index.html"]
                        else if htmlTime > orgTime
                        then do
                            putNormal "index.html is newer, updating index.org"
                            need ["index.org.from-html"]
                        else
                            putNormal "Files are in sync"
                    _ -> putNormal "Could not compare file times"

    "index.html" %> \out -> do
        -- Only generate if we're not in a sync operation or if explicitly called
        need ["index.org"]
        putNormal "pandoc index.org -o index.html --standalone"
        cmd_ "pandoc" ["index.org"] ["-o", out] ["--standalone"]
        cmd_ "mv index.org.tmp index.org"  -- It does work?
        -- putNormal "pandoc index.html -o index.org.tmp --to org"
        -- cmd_ "pandoc" ["index.html"] ["-o", "index.org.tmp"] ["--to", "org"]

    -- Special target to update org from HTML
    phony "index.org.from-html" $ do
        htmlExists <- doesFileExist "index.html"
        unless htmlExists $
            error "index.html does not exist"
        
        -- Convert HTML back to org
        putNormal "pandoc index.html -o index.org.tmp --to org"
        cmd_ "pandoc" ["index.html"] ["-o", "index.org.tmp"] ["--to", "org"]
        
        -- Read the generated org content
        -- tmpContent <- readFile' "index.org.tmp"
        
        -- -- Extract only the content part (skip the generated header)
        -- let contentLines = lines tmpContent
        -- let relevantLines = dropWhile (not . isPrefixOf "* pagefull") contentLines
        -- 
        -- -- Reconstruct with proper header
        -- let header = "#+STARTUP: inlineimages\n#+FILETAGS: :private:\n"
        -- let newContent = header ++ unlines relevantLines
        
        -- Write the final org file
        -- writeFile' "index.org" newContent -- Doesn't work
        cmd_ "cp index.org.tmp index.org"   -- Doesn't work either??
        
        -- Clean up temp file
        -- removeFilesAfter "." ["index.org.tmp"]
        
        putNormal "Updated index.org from index.html"
    
    -- Phony rule to rebuild everything
    phony "clean" $ do
        putNormal "Cleaning files"
        removeFilesAfter "." ["pagefull*.png"]
        removeFilesAfter "." ["index.org"]
        removeFilesAfter "." ["index.html"]
        removeFilesAfter "." ["index.org.tmp"]

