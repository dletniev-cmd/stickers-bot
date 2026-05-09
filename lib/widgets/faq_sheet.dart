import 'package:flutter/material.dart';
import '../theme.dart';

class FaqSheet extends StatelessWidget {
  const FaqSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Ответы на вопросы',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 20),
          _faqItem(
            context,
            q: 'Что такое Verify Age?',
            a: 'Verify Age — это приложение для подтверждения возраста. Оно использует камеру вашего устройства для быстрого сканирования и определения возраста.',
          ),
          const SizedBox(height: 10),
          _faqItem(
            context,
            q: 'Это безопасно?',
            a: 'Да, полностью. Видео не записывается и не отправляется на сервер. Вся обработка происходит локально на вашем устройстве.',
          ),
          const SizedBox(height: 10),
          _faqItem(
            context,
            q: 'Что делать, если проверка не прошла?',
            a: 'Убедитесь, что камера не заблокирована, лицо хорошо освещено и вы смотрите прямо в камеру. Попробуйте ещё раз.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _faqItem(BuildContext context, {required String q, required String a}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.keyBg(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.sub(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
