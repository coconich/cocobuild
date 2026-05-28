# cocobuild
past, present, and future versions of my build script(s)

I use this batch script in most of my projects to handle all my build needs.
It's main purposes for me are:
   - allow me to never have to open visual studio
   - let me iterate on building complex projects in single keybindings
   - wrangle the data and assets needed for packaged builds
   - allow me to control build steps very explicitly
     - metaprograms
     - shader compilation
     - asset packing/embedding
     - code generation
     - etc

I essentially structure my projects like this always, so there are bits of this script that will expect this.

```
|project
|--cocobuild.bat (THE BUILD SCRIPT)
|--clang (ouput directory, named based on compiler)
|----debug
|----release
|----release_with_debug
|----shipping
|--assets
|--data
|--src
|--shaders
|--external (vendored versions of dependencies, no package managing, no dynamic lib versioning)
|--libs     (actual .lib files, often just copied from external based on what i need/want from the library)
```

# Build Configurations
There are 4 built in configurations, extending configs would be fairly easy
```
Debug              : least optimizations, with debug info, builds pdb
ReleaseWithDebug   : some optimizations, with debug info, builds pdb
Release            : some optimizations, no debug info
Shipping           : all the flags, no debug info
```
You set the config you are building for within the script interface, and the configs are defined in your codebase for you.
```
EXE_NAME_CURRENT_BUILD_CONFIG
so if you set EXE_NAME=my_fun_project you end up with one of these defines
MY_FUN_PROJECT_DEBUG
MY_FUN_PROJECT_RELEASE_WITH_DEBUG
MY_FUN_PROJECT_RELEASE
MY_FUN_PROJECT_SHIPPING
```

# Project Files
I don't use visual studio for debugging personal projects (I usually use raddbg), so the lack of a project file is not much of an issue.
There is no plan to add support for things like msbuild, cmake, mason, makefiles, lua, or any other build solution/language/tool.
There is a plan to eventually support this in a more cross platform way, but I haven't decided on my approach yet.
```
1. compiled version of this build script in (annoying amount of work if c/c++, must learn new lang for others, but may be best for writing the gui)
2. keep parallel versions of .bat and .sh file and just keep them roughly synced (trivial to run on your OS)
3. port build script to python, or other equivalent interpreter (not as trivial to run)
```
# Build Recipes
Eventually, I want to be able to save the current configuration setups as "recipes" or whatever.
This would be useful for me to be able to quickly run different combinations of run args and configs.
Ideally, this is in a super basic txt format so I don't need other deps, and writing a build recipe gui would be easy.
