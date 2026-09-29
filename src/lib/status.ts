// docs/canonical.md v1.3 — 내부 상태값 30 (순서 = 허용 전이 순서). DB enum customer_status와 1:1.
export const CUSTOMER_STATUSES = [
  "신규 문의", "옵션 확인중", "옵션 선택 완료",
  "설문 작성 대기", "설문 제출 완료",
  "디렉터 자동 배정 완료", "캘린더 선택 대기", "고객 일정 선택 완료", "결제 확인 대기",
  "촬영일 확정 안내 발송 완료", "촬영 준비중", "전날 리마인드 발송 완료", "촬영 당일 대기",
  "고객 도착", "부가서비스 진행중", "의상 점검 완료", "촬영중", "중간 확인 완료", "촬영 완료",
  "셀렉 대기", "셀렉 완료", "보정 배정 완료", "보정중", "전달 완료",
  "후기 요청 발송", "후기 확인 대기", "후기 확인 완료", "원본 전달 대기", "원본 전달 완료", "후속관리중",
] as const;
export type CustomerStatus = (typeof CUSTOMER_STATUSES)[number];

export const STAGES = [
  { n: 1, label: "옵션 선택", statuses: CUSTOMER_STATUSES.slice(0, 3) },
  { n: 2, label: "설문", statuses: CUSTOMER_STATUSES.slice(3, 5) },
  { n: 3, label: "일정", statuses: CUSTOMER_STATUSES.slice(5, 9) },
  { n: 4, label: "촬영 준비", statuses: CUSTOMER_STATUSES.slice(9, 13) },
  { n: 5, label: "촬영", statuses: CUSTOMER_STATUSES.slice(13, 19) },
  { n: 6, label: "결과물", statuses: CUSTOMER_STATUSES.slice(19, 24) },
  { n: 7, label: "후속관리", statuses: CUSTOMER_STATUSES.slice(24, 30) },
] as const;
export type Stage = (typeof STAGES)[number]["n"];

export function stageOf(status: CustomerStatus): Stage {
  return STAGES.find((s) => (s.statuses as readonly string[]).includes(status))!.n;
}

export function nextStatus(status: CustomerStatus): CustomerStatus | null {
  const i = CUSTOMER_STATUSES.indexOf(status);
  return i >= 0 && i < CUSTOMER_STATUSES.length - 1 ? CUSTOMER_STATUSES[i + 1] : null;
}

/** 고객 화면용 "지금 할 일" 문구. 내부 status는 고객에게 보이지 않는다. */
export const STAGE_TODO: Record<Stage, string> = {
  1: "촬영 옵션을 골라주세요",
  2: "설문을 작성해주세요",
  3: "촬영 날짜를 선택해주세요",
  4: "촬영 준비 안내를 확인해주세요",
  5: "촬영 당일이에요",
  6: "결과물을 확인해주세요",
  7: "후속 혜택을 확인해주세요",
};
