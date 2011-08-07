{-# LANGUAGE OverloadedStrings #-}
module Main where

import Prelude hiding (id)
import Control.Arrow ((>>>), (***), arr)
import Control.Category (id)
import Control.Monad (forM_)
import Data.Monoid (mempty, mconcat)
import Text.Pandoc (WriterOptions(..), defaultWriterOptions)

import Hakyll

main :: IO ()
main = hakyll $ do
  
    -- Compress CSS
    match "stylesheets/*" $ do
      route   idRoute
      compile compressCssCompiler
    
    -- Copy images
    match "images/*" $ do
      route   idRoute
      compile copyFileCompiler
      
    -- Copy javascripts
    match "javascripts/*" $ do
      route   idRoute
      compile copyFileCompiler

    -- Copy files
    match "files/*" $ do
      route   idRoute
      compile copyFileCompiler

    -- Copy files
    match "patches/*" $ do
      route   idRoute
      compile copyFileCompiler
          
    -- Render posts
    match "posts/*" $ do
      route   $ setExtension ".html"
      compile $ wunkiCompiler
        >>> arr (renderDateField "date" "%Y-%m-%d" "Date unknown")
        >>> renderTagsField "prettytags" (fromCapture "tags/*")
        >>> applyTemplateCompiler "templates/post.html"
        >>> applyTemplateCompiler "templates/default.html"
        >>> relativizeUrlsCompiler

    -- Render posts list
    match "posts.html" $ route idRoute
    create "posts.html" $ constA mempty
      >>> arr (setField "title" "All posts")
      >>> requireAllA "posts/*" addPostList
      >>> applyTemplateCompiler "templates/posts.html"
      >>> applyTemplateCompiler "templates/default.html"
      >>> relativizeUrlsCompiler

    -- Index
    match "index.html" $ route idRoute
    create "index.html" $ constA mempty
      >>> arr (setField "title" "Wunki - a few bytes of Petar")
      >>> arr (setField "description" description)
      >>> arr (setField "keywords" keywords)
      >>> requireA "tags" (setFieldA "tagcloud" (renderTagCloud'))
      >>> requireAllA "posts/*" (id *** arr (take 10 . reverse . sortByBaseName) >>> addPostList)
      >>> applyTemplateCompiler "templates/index.html"
      >>> applyTemplateCompiler "templates/default.html"
      >>> relativizeUrlsCompiler

    -- Tags
    create "tags" $
      requireAll "posts/*" (\_ ps -> readTags ps :: Tags String)

    -- Add a tag list compiler for every tag
    match "tags/*" $ route $ setExtension ".html"
    metaCompile $ require_ "tags"
      >>> arr tagsMap
      >>> arr (map (\(t, p) -> (tagIdentifier t, makeTagList t p)))

    -- Render RSS feed
    match "rss.xml" $ route idRoute
    create "rss.xml" $
      requireAll_ "posts/*"
        >>> mapCompiler (arr $ copyBodyToField "description")
        >>> renderRss feedConfiguration
            
    -- Read templates
    match "templates/*" $ compile templateCompiler
    
        -- Render some static pages
    forM_ ["about.markdown", "404.markdown"] $ \p ->
        match p $ do
            route $ setExtension ".html"
            compile $ wunkiCompiler
                >>> applyTemplateCompiler "templates/default.html"
                >>> relativizeUrlsCompiler

  where
    renderTagCloud' :: Compiler (Tags String) String
    renderTagCloud' = renderTagCloud tagIdentifier 100 120

    tagIdentifier :: String -> Identifier (Page String)
    tagIdentifier = fromCapture "tags/*"
    
      -- Common variables
    description = "Wunki is a few bits on the web placed there by Petar Radosevic. A place with ramblings about programming, server setups and personal experiences. You can either find the posts a few pixels down or read more about me."
    keywords = "petar, radosevic, wunki, clojure, python, haskell, freebsd, django, api"

-- | Auxiliary compiler: generate a post list from a list of given posts, and
-- add it to the current page under @$posts@
--
addPostList :: Compiler (Page String, [Page String]) (Page String)
addPostList = setFieldA "posts" $
    arr (reverse . sortByBaseName)
        >>> require "templates/postitem.html" (\p t -> map (applyTemplate t) p)
        >>> arr mconcat
        >>> arr pageBody

makeTagList :: String
            -> [Page String]
            -> Compiler () (Page String)
makeTagList tag posts =
    constA (mempty, posts)
        >>> addPostList
        >>> arr (setField "title" ("Posts tagged &#8216;" ++ tag ++ "&#8217;"))
        >>> applyTemplateCompiler "templates/posts.html"
        >>> applyTemplateCompiler "templates/default.html"

-- | Read a page, add default fields, substitute fields and render with Pandoc.
--
wunkiCompiler :: Compiler Resource (Page String)
wunkiCompiler = pageCompilerWith defaultHakyllParserState wunkiWriterOptions
        
-- | Custom HTML options for pandoc        
--
wunkiWriterOptions :: WriterOptions
wunkiWriterOptions = defaultHakyllWriterOptions
  { writerHtml5 = True
  , writerTableOfContents = True
  }

config :: HakyllConfiguration
config = defaultHakyllConfiguration
    { deployCommand = "rsync --checksum -ave _site/* /Volumes/wunki-blog/wunki" }
    
feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration
    { feedTitle = "Wunki"
    , feedDescription = "A Few Bytes of Petar Radosevic"
    , feedAuthorName = "Petar Radosevic"
    , feedRoot = "http://www.wunki.org"
    }

