cmake_minimum_required(VERSION 3.16)
project(EventPointReminderDemo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Multimedia)

qt_add_executable(EventPointReminderDemo
    demo/main.cpp
    src/core/EventPoint.h
    src/ui/EventPointFullscreenReminder.h
    src/ui/EventPointFullscreenReminder.cpp
)

target_include_directories(EventPointReminderDemo PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

target_link_libraries(EventPointReminderDemo PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Multimedia
)

if(MSVC)
    target_compile_options(EventPointReminderDemo PRIVATE /utf-8)
endif()

# 与主程序一样从 ./sounds/countdown.wav 读取提示音
add_custom_command(TARGET EventPointReminderDemo POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/sounds $<TARGET_FILE_DIR:EventPointReminderDemo>/sounds
)
