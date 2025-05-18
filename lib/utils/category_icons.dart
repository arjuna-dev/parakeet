import 'package:flutter/material.dart';

class CategoryIcons {
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'At the Coffee Shop':
        return Icons.coffee;
      case 'Weather Talk':
        return Icons.wb_sunny;
      case 'In the Supermarket':
        return Icons.shopping_cart;
      case 'Asking for Directions':
        return Icons.map;
      case 'Making Small Talk':
        return Icons.chat_bubble;
      case 'At the Airport':
        return Icons.flight;
      case 'At the Restaurant':
        return Icons.restaurant;
      case 'At the Hotel':
        return Icons.hotel;
      case 'At the Doctor\'s Office':
        return Icons.local_hospital;
      case 'Public Transportation':
        return Icons.directions_bus;
      case 'Shopping for Clothes':
        return Icons.shopping_bag;
      case 'At the Gym':
        return Icons.fitness_center;
      case 'At the Bank':
        return Icons.account_balance;
      case 'At the Post Office':
        return Icons.local_post_office;
      case 'At the Pharmacy':
        return Icons.local_pharmacy;
      case 'At the Park':
        return Icons.park;
      case 'At the Beach':
        return Icons.beach_access;
      case 'At the Library':
        return Icons.library_books;
      case 'At the Cinema':
        return Icons.movie;
      case 'At the Hair Salon':
        return Icons.content_cut;
      case 'Custom Lesson':
        return Icons.create;
      default:
        return Icons.category;
    }
  }
}
