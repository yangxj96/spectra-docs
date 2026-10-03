import { createPinia, setActivePinia } from "pinia";
import { afterEach, describe, expect, it } from "vitest";
import { effectScope, ref, type EffectScope } from "vue";

import { RequestCancelledError } from "@/plugin/request/error";

import { useTable } from "./hook-full";
import { useExampleUserStore } from "./store-full";

type Row = { id: string };

function deferred<T>() {
    let resolve!: (value: T) => void;
    let reject!: (reason: unknown) => void;
    const promise = new Promise<T>((accept, decline) => {
        resolve = accept;
        reject = decline;
    });
    return { promise, resolve, reject };
}

function page(id: string): Page<Row> {
    return {
        current: 1,
        size: 10,
        total: 1,
        pages: 1,
        records: [{ id }],
        optimize_count_sql: true,
        search_count: true
    };
}

const scopes: EffectScope[] = [];
afterEach(() => {
    for (const scope of scopes) scope.stop();
    scopes.length = 0;
});

function setupTable(request: (params: BasePageParams) => Promise<Page<Row>>) {
    const scope = effectScope();
    scopes.push(scope);
    const scopeKey = ref("session-a");
    const table = scope.run(() => useTable(request, { page_num: 1, page_size: 10 }, scopeKey));
    if (!table) throw new Error("测试作用域未创建");
    return { scope, scopeKey, table };
}

describe("分页查询的可观察行为", () => {
    it("旧响应不能覆盖更新查询，也不能提前释放新请求的 loading", async () => {
        const first = deferred<Page<Row>>();
        const second = deferred<Page<Row>>();
        const { table } = setupTable(params => (params.page_num === 1 ? first.promise : second.promise));
        const earlier = table.fetchData();
        const later = table.handleCurrentChange(2);

        first.resolve(page("old"));
        await earlier;
        expect(table.loading.value).toBe(true);
        expect(table.tableData.value).toEqual([]);

        second.resolve(page("current"));
        await later;
        expect(table.tableData.value).toEqual([{ id: "current" }]);
        expect(table.loading.value).toBe(false);
    });

    it("切换身份立即清理数据，并拒绝上一会话的迟到响应", async () => {
        const pending = deferred<Page<Row>>();
        let next = Promise.resolve(page("visible"));
        const { table, scopeKey } = setupTable(() => next);
        await table.fetchData();
        next = pending.promise;
        const result = table.fetchData();

        scopeKey.value = "session-b";
        expect(table.tableData.value).toEqual([]);
        pending.resolve(page("previous-session"));
        await result;
        expect(table.tableData.value).toEqual([]);
        expect(table.loading.value).toBe(false);
    });

    it("失败保留可识别错误并释放 loading，主动取消不变成失败提示", async () => {
        const failure = new Error("查询失败");
        let next: Promise<Page<Row>> | undefined;
        const { table } = setupTable(() => {
            if (!next) throw new Error("测试请求未准备");
            return next;
        });
        next = Promise.reject(failure);
        await table.fetchData();
        expect(table.error.value).toBe(failure);
        expect(table.loading.value).toBe(false);

        next = Promise.reject(new RequestCancelledError());
        await table.fetchData();
        expect(table.error.value).toBeUndefined();
        expect(table.loading.value).toBe(false);
    });

    it("销毁作用域后迟到响应不能重新写入状态", async () => {
        const pending = deferred<Page<Row>>();
        const { table, scope } = setupTable(() => pending.promise);
        const result = table.fetchData();
        scope.stop();
        pending.resolve(page("late"));
        await result;
        expect(table.tableData.value).toEqual([]);
        expect(table.loading.value).toBe(false);
    });
});

describe("会话共享状态", () => {
    it("退出登录清除身份和权限，下一身份不继承旧权限", () => {
        setActivePinia(createPinia());
        const store = useExampleUserStore();
        const token: Token = {
            id: "user-a",
            username: "first",
            access_token: "example-only",
            permissions: ["user:read"]
        };
        store.setAuth(token);
        expect(store.hasPermission("user:read")).toBe(true);
        store.clearAuth();
        expect(store.isLoggedIn).toBe(false);
        expect(store.getPermissions).toEqual([]);
        store.setAuth({ ...token, id: "user-b", permissions: ["file:read"] });
        expect(store.hasPermission("user:read")).toBe(false);
        expect(store.hasPermission("file:read")).toBe(true);
    });
});
