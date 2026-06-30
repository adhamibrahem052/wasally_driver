# Wasally Driver — AI Coding Rules

## المشروع
تطبيق سائق Flutter يستخدم Riverpod + Supabase + GoRouter.
Supabase Project: oyrexsyebgplfretcvko

## ⚠️ قاعدة العقد المشترك
الجداول التالية يكتب عليها تطبيق آخر (Customer App) أيضاً:
- orders — العميل يقرأ منه ويتابع حالته في real-time
- notifications — العميل يستقبل منه إشعارات
- complaints / messages — chat مشترك بين السائق والعميل

قبل أي تعديل على هذه الجداول أو RLS policies الخاصة بها:
قل لي "هذا التعديل سيأثر على Customer App أيضاً" وانتظر موافقتي.

## قواعد Riverpod (لا تكسرها أبداً)
- لا تستخدم ref.invalidate() أو ref.refresh() على driverOrdersProvider
- driverOrdersProvider هو StreamProvider غير autoDispose — الـ realtime 
  يوصّل التحديثات تلقائياً، لا تقطع الاتصال
- أي provider جديد للـ stream: لا تضف autoDispose إلا لو الشاشة بتتدمر

## قواعد SupabaseClient
- لا تستخدم Supabase.instance.client مباشرة في أي ملف
- استخدم دائماً: ref.read(supabaseClientProvider)
- كل service جديد يأخذ SupabaseClient في الـ constructor

## قواعد Navigation
- لا تكتب context.go() أو context.push() بعد أي auth mutation
- GoRouter redirect في router_provider.dart يتحكم في كل التنقل

## قبل كتابة أي provider جديد
ابحث أولاً في lib/driver/providers/ و lib/shared/providers/
إذا وجدت provider مشابه — أعد استخدامه، لا تنشئ نسخة جديدة
