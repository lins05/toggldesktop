// Copyright 2014 Toggl Desktop developers.

#ifndef SRC_UI_LINUX_TOGGLDESKTOP_TIMERWIDGET_H_
#define SRC_UI_LINUX_TOGGLDESKTOP_TIMERWIDGET_H_

#include <QWidget>
#include <QVector>
#include <QTimer>
#include <QLabel>
#include <QFrame>

namespace Ui {
class TimerWidget;
}

class AutocompleteListModel;
class AutocompleteView;
class TimeEntryView;

class TimerWidget : public QFrame {
    Q_OBJECT

 public:
    explicit TimerWidget(QWidget *parent = 0);
    ~TimerWidget();

 private:

 signals:
    void buttonClicked();

 protected:
    void mousePressEvent(QMouseEvent *event);
    void resizeEvent(QResizeEvent *) override;

 private slots:  // NOLINT
    void displayStoppedTimerState();

    void displayRunningTimerState(
        TimeEntryView *te);

    void displayMinitimerAutocomplete(
        QVector<AutocompleteView *> list);

    void start();
    void stop();

    void timeout();

    void focusChanged(QWidget *old, QWidget *now);
    void on_start_clicked();

    void on_duration_returnPressed();

    void descriptionReturnPressed();
    void descriptionProjectSelected(const QString &projectName, uint64_t projectId, const QString &color, const QString &taskName, uint64_t taskId);
    void descriptionBillableChanged(bool billable);
    void descriptionTagsChanged(const QString &tags);

    void clearProject();
    void clearTask();

    void updateCoverLabel(const QString &text);

 private:
    Ui::TimerWidget *ui;

    QTimer *timer;

    int64_t duration;

    QString project;
    QString descriptionPlaceholder;
    QString tagsHolder;

    bool timeEntryAutocompleteNeedsUpdate;
    QVector<AutocompleteView *> timeEntryAutocompleteUpdate;
    AutocompleteListModel *descriptionModel;

    uint64_t selectedTaskId;
    uint64_t selectedProjectId;

    QString guid;

    void setEllipsisTextToLabel(QLabel *label, QString text);
};

#endif  // SRC_UI_LINUX_TOGGLDESKTOP_TIMERWIDGET_H_
