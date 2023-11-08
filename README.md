# Examples #

This is the public repository for simple examples developed with Ecstasy to be deployed
on the XQIZ.IT hosting platform.

## Layout ##

We assume the following application layout:

     myApp/                         <- the project root
      |- server/                     <- the back end source (Ecstasy-base)
      |  |- build.gradle.kts         <- the gradle build script for the server components
      |  |- main/
      |     |- resources/            <- static resources
      |     |  |- webapp             <- the directory to copy the application web content
      |     |    |- index.html       <- the landing page
      |     |    |- ...
      |     |- x/                    <- source code directory
      |     |  |- myApp.x            <- application module file
      |     |  |- myApp/
      |     |     |- ...             <- application packages and classes
      |
      |- webapp/                     <- the gui (html- and js-based)
      |  |- build.gradle.kts         <- the gradle build script for the server components
      |  |- package.json             <- the project metadata
      |  |- public/                  <- static web resources (.html, .ico, .png, ...) 
      |     |- index.html            <- the landing page
      |  |  |- ...
      |  |- src/                  <- javascript source root
      |  |     |- index.js           <- the landing page source
      |  |     |- App.js             <- application components
      |  |     |- ...
      |  | 
      |- README.md
      |- build.gradle.kts

## Steps to test the examples

As a temporary process, do the following:

1. Follow the instructions from the [PAAS setup](https://github.com/xtclang/platform/blob/master/README.md#steps-to-test-the-paas-functionality) 
   repository to start the hosting site.

2. To develop a stand-alone (disconnected) web-site using NPM, install it in myApp/webapp directory. 
   
       cd myApp/webapp 
       npm install
       npm start

3. Use the platform UI to upload and run the applications
