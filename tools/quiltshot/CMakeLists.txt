# quiltshot: loads a QML window, plays a script of input and saves
# screenshots of whole windows, popups included. A developer tool for
# checking visuals headlessly; Quilt itself needs no build.
#
#   cmake -S tools/quiltshot -B build/quiltshot && cmake --build build/quiltshot
#   QT_QPA_PLATFORM=offscreen build/quiltshot/quiltshot examples/gallery.qml script.txt
#
# See docs/testing.md, "Headless screenshots".

cmake_minimum_required(VERSION 3.21)
project(quiltshot LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick Test)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(quiltshot main.cpp)
target_link_libraries(quiltshot PRIVATE Qt6::Quick Qt6::Test)
