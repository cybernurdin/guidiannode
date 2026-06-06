const crypto = require('crypto');

const { supabaseAdmin } = require('../config/supabaseClient');
const { AppError, wrapDatabaseError } = require('../utils/appError');
const { nowIso } = require('../utils/authUtils');

const USERS_TABLE = 'users';
const EMERGENCY_CONTACTS_TABLE = 'emergency_contacts';
const AUTH_USERS_PAGE_SIZE = 200;

const isSchemaCacheMissingColumn = (error, relationName, columnName) => {
  const haystack = [error?.message, error?.details, error?.hint]
    .filter(Boolean)
    .join(' ');
  const match = haystack.match(
    /could not find the ['"]([^'"]+)['"] column of ['"]([^'"]+)['"] in the schema cache/i
  );

  if (!match) {
    return false;
  }

  const [, reportedColumnName, reportedRelationName] = match;

  return (
    reportedRelationName.toLowerCase() === String(relationName).toLowerCase() &&
    reportedColumnName.toLowerCase() === String(columnName).toLowerCase()
  );
};

const insertWithCreatedAtFallback = async (tableName, payload) => {
  let { data, error } = await supabaseAdmin
    .from(tableName)
    .insert(payload)
    .select()
    .single();

  if (error && isSchemaCacheMissingColumn(error, tableName, 'created_at')) {
    const fallbackPayload = { ...payload };
    delete fallbackPayload.created_at;

    ({ data, error } = await supabaseAdmin
      .from(tableName)
      .insert(fallbackPayload)
      .select()
      .single());
  }

  if (error) {
    throw wrapDatabaseError(error, tableName);
  }

  return data;
};

const buildUserProfile = (user, emergencyContact = null) => ({
  ...user,
  emergency_contact: emergencyContact,
});

const getUserById = async (userId) => {
  const { data, error } = await supabaseAdmin
    .from(USERS_TABLE)
    .select('*')
    .eq('id', userId)
    .maybeSingle();

  if (error) {
    throw wrapDatabaseError(error, USERS_TABLE);
  }

  return data;
};

const getUserByPhoneNumber = async (phoneNumber) => {
  const { data, error } = await supabaseAdmin
    .from(USERS_TABLE)
    .select('*')
    .eq('phone_number', phoneNumber)
    .maybeSingle();

  if (error) {
    throw wrapDatabaseError(error, USERS_TABLE);
  }

  return data;
};

const listAuthUsersPage = async (page) => {
  const { data, error } = await supabaseAdmin.auth.admin.listUsers({
    page,
    perPage: AUTH_USERS_PAGE_SIZE,
  });

  if (error) {
    throw new AppError(
      'Unable to inspect Supabase auth users while provisioning the app profile.',
      500,
      'auth_admin_list_users_failed',
      error
    );
  }

  return data;
};

const findAuthUserByPhoneNumber = async (phoneNumber) => {
  let currentPage = 1;

  while (currentPage) {
    const pageData = await listAuthUsersPage(currentPage);
    const users = Array.isArray(pageData?.users) ? pageData.users : [];
    const matchingUser = users.find((user) => user.phone === phoneNumber);

    if (matchingUser) {
      return matchingUser;
    }

    if (Number.isInteger(pageData?.nextPage) && pageData.nextPage > currentPage) {
      currentPage = pageData.nextPage;
      continue;
    }

    if (Number.isInteger(pageData?.lastPage) && currentPage < pageData.lastPage) {
      currentPage += 1;
      continue;
    }

    break;
  }

  return null;
};

const ensureAuthUserForPhoneNumber = async ({ phoneNumber, fullName }) => {
  const { data, error } = await supabaseAdmin.auth.admin.createUser({
    phone: phoneNumber,
    password: `${crypto.randomUUID()}Aa1!`,
    phone_confirm: true,
    user_metadata: {
      full_name: fullName,
      guardian_node_auth_flow: 'whatsapp_inbound',
    },
  });

  if (!error && data?.user) {
    return data.user;
  }

  const errorCode = String(error?.code ?? '').toLowerCase();
  const errorMessage = String(error?.message ?? '').toLowerCase();
  const looksLikeExistingAuthUser =
    ['phone_exists', 'user_already_exists', 'conflict'].includes(errorCode) ||
    errorMessage.includes('already') ||
    errorMessage.includes('exists');

  if (looksLikeExistingAuthUser) {
    const existingAuthUser = await findAuthUserByPhoneNumber(phoneNumber);

    if (existingAuthUser) {
      return existingAuthUser;
    }
  }

  throw new AppError(
    'Unable to provision the matching Supabase auth user for this phone number.',
    500,
    'auth_user_provision_failed',
    error
  );
};

const saveUserProfile = async (userData) => {
  const {
    id,
    full_name,
    phone_number,
    quarter,
    location_permission,
    latitude,
    longitude,
  } = userData;

  const existingUser = await getUserById(id);
  const payload = {
    full_name,
    phone_number,
    quarter,
    location_permission: Boolean(location_permission),
    latitude: location_permission ? latitude ?? null : null,
    longitude: location_permission ? longitude ?? null : null,
  };

  if (existingUser) {
    const { data, error } = await supabaseAdmin
      .from(USERS_TABLE)
      .update(payload)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw wrapDatabaseError(error, USERS_TABLE);
    }

    return data;
  }

  return insertWithCreatedAtFallback(USERS_TABLE, {
    id,
    ...payload,
    created_at: nowIso(),
  });
};

const markUserPhoneVerified = async (user) => {
  const verifiedAt = nowIso();
  let verifiedUser = user;
  let { data, error } = await supabaseAdmin
    .from(USERS_TABLE)
    .update({
      phone_verified: true,
      phone_verified_at: verifiedAt,
    })
    .eq('id', user.id)
    .select()
    .single();

  if (
    error &&
    (
      isSchemaCacheMissingColumn(error, USERS_TABLE, 'phone_verified') ||
      isSchemaCacheMissingColumn(error, USERS_TABLE, 'phone_verified_at')
    )
  ) {
    error = null;
    data = null;
  }

  if (error) {
    throw wrapDatabaseError(error, USERS_TABLE);
  }

  if (data) {
    verifiedUser = data;
  }

  const { error: authError } = await supabaseAdmin.auth.admin.updateUserById(
    user.id,
    {
      phone_confirm: true,
    }
  );

  if (authError) {
    throw new AppError(
      'Unable to mark the matching Supabase auth user as phone verified.',
      500,
      'auth_user_phone_verification_failed',
      authError
    );
  }

  return verifiedUser;
};

const getPrimaryEmergencyContact = async (userId) => {
  const { data, error } = await supabaseAdmin
    .from(EMERGENCY_CONTACTS_TABLE)
    .select('*')
    .eq('user_id', userId)
    .limit(1);

  if (error) {
    throw wrapDatabaseError(error, EMERGENCY_CONTACTS_TABLE);
  }

  return data?.[0] ?? null;
};

const saveEmergencyContact = async (contactData) => {
  const { user_id, contact_name, phone_number, relationship } = contactData;
  const existingContact = await getPrimaryEmergencyContact(user_id);
  const payload = {
    user_id,
    contact_name,
    phone_number,
    relationship,
  };

  if (existingContact) {
    const { data, error } = await supabaseAdmin
      .from(EMERGENCY_CONTACTS_TABLE)
      .update(payload)
      .eq('id', existingContact.id)
      .select()
      .single();

    if (error) {
      throw wrapDatabaseError(error, EMERGENCY_CONTACTS_TABLE);
    }

    return data;
  }

  return insertWithCreatedAtFallback(EMERGENCY_CONTACTS_TABLE, {
    ...payload,
    created_at: nowIso(),
  });
};

const getUserProfile = async (userId) => {
  const user = await getUserById(userId);

  if (!user) {
    throw new AppError('User profile could not be found.', 404, 'user_not_found');
  }

  const emergencyContact = await getPrimaryEmergencyContact(userId);
  return buildUserProfile(user, emergencyContact);
};

const updateUserProfile = async ({
  userId,
  full_name,
  quarter,
  emergency_contact,
}) => {
  const existingUser = await getUserById(userId);

  if (!existingUser) {
    throw new AppError('User profile could not be found.', 404, 'user_not_found');
  }

  let user = existingUser;

  if (full_name !== undefined || quarter !== undefined) {
    user = await saveUserProfile({
      id: existingUser.id,
      full_name: full_name ?? existingUser.full_name,
      phone_number: existingUser.phone_number,
      quarter: quarter ?? existingUser.quarter,
      location_permission: existingUser.location_permission,
      latitude: existingUser.latitude,
      longitude: existingUser.longitude,
    });
  }

  let emergencyContact = await getPrimaryEmergencyContact(userId);

  if (emergency_contact) {
    emergencyContact = await saveEmergencyContact({
      user_id: userId,
      contact_name: emergency_contact.contact_name,
      phone_number: emergency_contact.phone_number,
      relationship: emergency_contact.relationship,
    });
  }

  return buildUserProfile(user, emergencyContact);
};

module.exports = {
  ensureAuthUserForPhoneNumber,
  findAuthUserByPhoneNumber,
  getPrimaryEmergencyContact,
  getUserById,
  getUserProfile,
  getUserByPhoneNumber,
  markUserPhoneVerified,
  saveEmergencyContact,
  saveUserProfile,
  updateUserProfile,
};
