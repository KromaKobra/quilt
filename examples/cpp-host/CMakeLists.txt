# A C++ application that embeds Quilt as compiled QML modules and edits a
# C++ object (shape.h) with Quilt's controls.
#
#   cmake -S examples/cpp-host -B build/cpp-host
#   cmake --build build/cpp-host
#   ./build/cpp-host/quilt-cpp-host

cmake_minimum_required(VERSION 3.21)
project(QuiltCppHost LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2)
qt_standard_project_setup(REQUIRES 6.8)

# Point this at your copy of the Quilt folder. (The second argument names the
# build directory; keeping it "Quilt" keeps Qt's tooling happy.)
add_subdirectory(../../Quilt Quilt)

qt_add_executable(quilt-cpp-host main.cpp)
qt_add_qml_module(quilt-cpp-host
    URI CppHost
    QML_FILES Main.qml
    SOURCES shape.h
)

# Quilt::Quilt is every module. Quilt::Docking or Quilt::Controls alone
# also work, if that is all the application imports.
target_link_libraries(quilt-cpp-host PRIVATE Qt6::Quick Quilt::Quilt)
