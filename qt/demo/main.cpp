// 事件点全屏提醒 · 独立预览程序
//   直接运行：在主屏上播放一次（加 --loop 循环）
//   --dump <目录>：把关键帧渲染成 PNG，叠在一张假桌面上，不弹窗口

#include "ui/EventPointFullscreenReminder.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QImage>
#include <QLinearGradient>
#include <QPainter>
#include <QScreen>
#include <QTimer>

#include <functional>

namespace {

void paintDesktop(QImage& image)
{
    QPainter painter(&image);
    QLinearGradient wallpaper(0, 0, image.width(), image.height());
    wallpaper.setColorAt(0, QColor(61, 111, 152));
    wallpaper.setColorAt(1, QColor(12, 22, 34));
    painter.fillRect(image.rect(), wallpaper);
    const qreal u = image.height() / 1080.0;
    painter.fillRect(QRectF(image.width() / 2 - 700 * u, 140 * u, 1060 * u, 660 * u), QColor(238, 240, 243));
    painter.fillRect(QRectF(0, image.height() - 48 * u, image.width(), 48 * u), QColor(22, 26, 32, 230));
}

} // namespace

int main(int argc, char* argv[])
{
    QApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.addHelpOption();
    const QCommandLineOption nameOption("name", "事件名称", "name", "放学");
    const QCommandLineOption timeOption("time", "事件时间 HH:mm:ss", "time", "17:40:00");
    const QCommandLineOption flashOption("flash", "闪烁 / 提示音次数", "n", "3");
    const QCommandLineOption loopOption("loop", "循环播放");
    const QCommandLineOption dumpOption("dump", "把关键帧渲染成 PNG 到该目录", "dir");
    const QCommandLineOption sizeOption("size", "--dump 的画面尺寸", "WxH", "1920x1080");
    parser.addOptions({ nameOption, timeOption, flashOption, loopOption, dumpOption, sizeOption });
    parser.process(app);

    const QTime time = QTime::fromString(parser.value(timeOption), "HH:mm:ss");
    const EventPoint eventPoint(time.isValid() ? time : QTime(17, 40), parser.value(nameOption), 60);
    // ConfigManager 的默认事件点列表，用来显示“下一个事件点”
    const QList<EventPoint> eventPointList = {
        EventPoint(QTime(11, 55), "放学", 60),
        EventPoint(QTime(17, 40), "放学", 60),
        EventPoint(QTime(22, 0), "放学", 60),
    };
    const int flashTimes = parser.value(flashOption).toInt();

    if (parser.isSet(dumpOption)) {
        QDir dir(parser.value(dumpOption));
        dir.mkpath(".");
        const QStringList wh = parser.value(sizeOption).split('x');
        const QSize size(qMax(320, wh.value(0).toInt()), qMax(180, wh.value(1).toInt()));

        EventPointFullscreenReminder reminder(eventPoint, eventPointList, QRect(), flashTimes);
        reminder.setAttribute(Qt::WA_DeleteOnClose, false);
        reminder.resize(size);
        const qreal end = reminder.totalDuration();
        for (const qreal t : { 150.0, 480.0, 800.0, 960.0, 1200.0, 1500.0, 1850.0, 2300.0, 2700.0, end - 900, end - 400 }) {
            QImage frame(size, QImage::Format_ARGB32_Premultiplied);
            paintDesktop(frame);
            reminder.seek(t);
            QPainter painter(&frame);
            reminder.render(&painter, QPoint(), QRegion(), QWidget::DrawChildren);
            painter.end();
            frame.save(dir.filePath(QString("frame_%1.png").arg(qRound(t), 5, 10, QChar('0'))));
        }
        return 0;
    }

    // 模拟 EventPointReminder 胶囊在到点那一刻的位置（显示“1”时的宽度）
    const QRect screen = QApplication::primaryScreen()->geometry();
    const int capsuleHeight = qRound(screen.width() * 0.05);
    const int capsuleWidth = qRound(capsuleHeight * 0.6);
    const QRect capsule(screen.x() + (screen.width() - capsuleWidth) / 2, screen.y() + qRound(screen.height() * 0.1),
                        capsuleWidth, capsuleHeight);
    const bool loop = parser.isSet(loopOption);

    std::function<void()> play = [&] {
        auto* reminder = new EventPointFullscreenReminder(eventPoint, eventPointList, capsule, flashTimes);
        QObject::connect(reminder, &EventPointFullscreenReminder::finished, &app, [&] {
            if (loop) QTimer::singleShot(1000, &app, play);
            else QTimer::singleShot(0, &app, &QApplication::quit);
            });
        reminder->start();
    };
    play();
    return app.exec();
}
