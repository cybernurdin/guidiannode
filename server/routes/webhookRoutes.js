const express = require('express');

const whatsappWebhookController = require('../controllers/whatsappWebhookController');

const router = express.Router();

router.get('/', whatsappWebhookController.verifyWebhookHandler);
router.post('/', whatsappWebhookController.receiveWebhookHandler);

module.exports = router;
