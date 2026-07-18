-- ============================================
-- 消息中心相关表
-- ============================================

-- -------------------------------------------
-- 1. 系统通知消息表
-- -------------------------------------------
DROP TABLE IF EXISTS "spectra_core"."sys_notification";
CREATE TABLE "spectra_core"."sys_notification"
(
    ------------- 主键字段
    "id"            uuid           NOT NULL,
    ------------- 业务字段
    "title"         VARCHAR(255)   NOT NULL,
    "content"       TEXT,
    "type"          VARCHAR(50)    NOT NULL,
    "sender_id"     uuid,
    "sender_name"   VARCHAR(100),
    "link"          VARCHAR(500),
    "is_read"       bool           NOT NULL DEFAULT false,
    "read_at"       timestamptz(6),
    "receiver_id"   uuid           NOT NULL,
    "extra"         jsonb,
    ------------- 审计字段
    "created_by"    uuid,
    "created_at"    timestamptz(6) NOT NULL,
    "updated_by"    uuid,
    "updated_at"    timestamptz(6) NOT NULL,
    "deleted"       timestamptz(6),
    "version"       int8           DEFAULT 0
);

COMMENT ON TABLE "spectra_core"."sys_notification" IS '系统通知消息表';

------------- 主键字段
COMMENT ON COLUMN "spectra_core"."sys_notification"."id" IS '主键ID';

------------- 业务字段
COMMENT ON COLUMN "spectra_core"."sys_notification"."title" IS '消息标题';
COMMENT ON COLUMN "spectra_core"."sys_notification"."content" IS '消息内容';
COMMENT ON COLUMN "spectra_core"."sys_notification"."type" IS '消息类型：system-系统通知, workflow-工作流通知, oa-OA通知, inner_mail-站内信, approval-待我审批';
COMMENT ON COLUMN "spectra_core"."sys_notification"."sender_id" IS '发送者ID（站内信场景）';
COMMENT ON COLUMN "spectra_core"."sys_notification"."sender_name" IS '发送者名称（冗余字段，避免频繁JOIN）';
COMMENT ON COLUMN "spectra_core"."sys_notification"."link" IS '点击跳转路径';
COMMENT ON COLUMN "spectra_core"."sys_notification"."is_read" IS '是否已读：true-已读, false-未读';
COMMENT ON COLUMN "spectra_core"."sys_notification"."read_at" IS '阅读时间';
COMMENT ON COLUMN "spectra_core"."sys_notification"."receiver_id" IS '接收者ID（消息归属用户）';
COMMENT ON COLUMN "spectra_core"."sys_notification"."extra" IS '扩展数据（JSON格式，如流程实例ID、会议ID等）';

------------- 审计字段
COMMENT ON COLUMN "spectra_core"."sys_notification"."created_by" IS '创建人';
COMMENT ON COLUMN "spectra_core"."sys_notification"."created_at" IS '创建时间';
COMMENT ON COLUMN "spectra_core"."sys_notification"."updated_by" IS '最后更新人';
COMMENT ON COLUMN "spectra_core"."sys_notification"."updated_at" IS '最后更新时间';
COMMENT ON COLUMN "spectra_core"."sys_notification"."deleted" IS '删除标识（逻辑删除）';
COMMENT ON COLUMN "spectra_core"."sys_notification"."version" IS '乐观锁';

------------- 约束
ALTER TABLE "spectra_core"."sys_notification"
    ADD CONSTRAINT "sys_notification_pkey" PRIMARY KEY ("id");

------------- 索引
CREATE INDEX "idx_notification_receiver_id" ON "spectra_core"."sys_notification" ("receiver_id");
CREATE INDEX "idx_notification_is_read" ON "spectra_core"."sys_notification" ("is_read");
CREATE INDEX "idx_notification_type" ON "spectra_core"."sys_notification" ("type");
CREATE INDEX "idx_notification_created_at" ON "spectra_core"."sys_notification" ("created_at" DESC);

COMMENT ON INDEX "spectra_core"."idx_notification_receiver_id" IS '接收者ID索引';
COMMENT ON INDEX "spectra_core"."idx_notification_is_read" IS '已读状态索引';
COMMENT ON INDEX "spectra_core"."idx_notification_type" IS '消息类型索引';
COMMENT ON INDEX "spectra_core"."idx_notification_created_at" IS '创建时间索引（降序）';


-- -------------------------------------------
-- 2. 用户通知设置表
-- -------------------------------------------
DROP TABLE IF EXISTS "spectra_core"."sys_notification_setting";
CREATE TABLE "spectra_core"."sys_notification_setting"
(
    ------------- 主键字段
    "id"                  uuid           NOT NULL,
    ------------- 业务字段
    "user_id"             uuid           NOT NULL,
    "system_enabled"      bool           NOT NULL DEFAULT true,
    "workflow_enabled"    bool           NOT NULL DEFAULT true,
    "oa_enabled"          bool           NOT NULL DEFAULT true,
    "inner_mail_enabled"  bool           NOT NULL DEFAULT true,
    "approval_enabled"    bool           NOT NULL DEFAULT true,
    "do_not_disturb"      bool           NOT NULL DEFAULT false,
    "do_not_disturb_start" time,
    "do_not_disturb_end"  time,
    ------------- 审计字段
    "created_by"          uuid,
    "created_at"          timestamptz(6) NOT NULL,
    "updated_by"          uuid,
    "updated_at"          timestamptz(6) NOT NULL,
    "deleted"             timestamptz(6),
    "version"             int8           DEFAULT 0
);

COMMENT ON TABLE "spectra_core"."sys_notification_setting" IS '用户通知设置表';

------------- 主键字段
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."id" IS '主键ID';

------------- 业务字段
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."user_id" IS '用户ID（一对一关联）';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."system_enabled" IS '是否接收系统通知：true-接收, false-不接收';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."workflow_enabled" IS '是否接收工作流通知：true-接收, false-不接收';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."oa_enabled" IS '是否接收OA通知：true-接收, false-不接收';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."inner_mail_enabled" IS '是否接收站内信：true-接收, false-不接收';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."approval_enabled" IS '是否接收待审批通知：true-接收, false-不接收';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."do_not_disturb" IS '免打扰模式：true-开启, false-关闭';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."do_not_disturb_start" IS '免打扰开始时间（如22:00:00）';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."do_not_disturb_end" IS '免打扰结束时间（如08:00:00）';

------------- 审计字段
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."created_by" IS '创建人';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."created_at" IS '创建时间';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."updated_by" IS '最后更新人';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."updated_at" IS '最后更新时间';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."deleted" IS '删除标识（逻辑删除）';
COMMENT ON COLUMN "spectra_core"."sys_notification_setting"."version" IS '乐观锁';

------------- 约束
ALTER TABLE "spectra_core"."sys_notification_setting"
    ADD CONSTRAINT "sys_notification_setting_pkey" PRIMARY KEY ("id");

ALTER TABLE "spectra_core"."sys_notification_setting"
    ADD CONSTRAINT "uk_notification_setting_user_id" UNIQUE ("user_id");

------------- 索引
CREATE UNIQUE INDEX "idx_notification_setting_user_id" ON "spectra_core"."sys_notification_setting" ("user_id");

COMMENT ON INDEX "spectra_core"."idx_notification_setting_user_id" IS '用户ID唯一索引';
