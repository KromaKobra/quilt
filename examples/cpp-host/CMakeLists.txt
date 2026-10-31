# A C++ application that embeds Quilt as a compiled QML module.
#
#   cmake -S examples/cpp-host -B build/cpp-host
#   cmake --build build/cpp-host
#   ./build/cpp-host/quilt-cpp-host

cmake_minimum_required(VERSION 3.21)
project(QuiltCppHost LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2)
qt_standard_project_setup(REQUIRES 6.8)

# Point this at your copy of the Quilt folder.
add_subdirectory(../../Quilt quilt)

qt_add_executable(quilt-cpp-host main.cpp)
qt_add_qml_module(quilt-cpp-host
    URI CppHost
    QML_FILES Main.qml
)

target_link_libraries(quilt-cpp-host PRIVATE Qt6::Quick quiltplugin)
