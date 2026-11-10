package org.poulapp.poulplan

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.StatFs
import android.provider.ContactsContract
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Fragment activity for the biometric prompt (local_auth), plus the
 * `org.poulapp.poulplan/android` channel: save a document where the user
 * chooses, open an attachment or a navigation app, read the contacts'
 * birthdays, free space.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingSave: Pair<ByteArray, MethodChannel.Result>? = null
    private var pendingContacts: MethodChannel.Result? = null

    private val createDocument =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val (bytes, reply) = pendingSave ?: return@registerForActivityResult
            pendingSave = null
            val uri = result.data?.data
            if (result.resultCode != Activity.RESULT_OK || uri == null) {
                reply.success(false)
                return@registerForActivityResult
            }
            try {
                contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes) }
                reply.success(true)
            } catch (e: Exception) {
                reply.error("WRITE_FAILED", e.message, null)
            }
        }

    private val contactsPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            val reply = pendingContacts ?: return@registerForActivityResult
            pendingContacts = null
            if (granted) reply.success(readBirthdays())
            else reply.error("PERMISSION_DENIED", "READ_CONTACTS refused", null)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BRouterBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.poulapp.poulplan/android")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUri" -> {
                        // geo: link → the navigation apps installed (OsmAnd,
                        // Organic Maps…), the user picks one.
                        val view = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("uri")!!))
                        try {
                            startActivity(Intent.createChooser(view, call.argument<String>("title")))
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.error("NO_APP", e.message, null)
                        }
                    }
                    "saveDocument" -> {
                        pendingSave = Pair(call.argument<ByteArray>("bytes")!!, result)
                        createDocument.launch(
                            Intent(Intent.ACTION_CREATE_DOCUMENT)
                                .addCategory(Intent.CATEGORY_OPENABLE)
                                .setType(call.argument<String>("mime")!!)
                                .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name")!!),
                        )
                    }
                    "contactBirthdays" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this, Manifest.permission.READ_CONTACTS,
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(readBirthdays())
                        } else {
                            pendingContacts = result
                            contactsPermission.launch(Manifest.permission.READ_CONTACTS)
                        }
                    }
                    "openFile" -> {
                        val file = java.io.File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
                        val view = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, call.argument<String>("mime")!!)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        try {
                            startActivity(Intent.createChooser(view, file.name))
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.error("NO_APP", e.message, null)
                        }
                    }
                    "freeBytes" -> result.success(StatFs(call.argument<String>("path")!!).availableBytes)
                    else -> result.notImplemented()
                }
            }
    }

    /** Name and birthday date (as stored, e.g. `1996-04-12` or `--04-12`). */
    private fun readBirthdays(): List<Map<String, String>> {
        val projection = arrayOf(
            ContactsContract.Data.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Event.START_DATE,
        )
        val selection = "${ContactsContract.Data.MIMETYPE} = ? AND " +
            "${ContactsContract.CommonDataKinds.Event.TYPE} = ?"
        val args = arrayOf(
            ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE,
            ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY.toString(),
        )
        val birthdays = mutableListOf<Map<String, String>>()
        contentResolver.query(ContactsContract.Data.CONTENT_URI, projection, selection, args, null)
            ?.use { cursor ->
                while (cursor.moveToNext()) {
                    val name = cursor.getString(0) ?: continue
                    val date = cursor.getString(1) ?: continue
                    birthdays.add(mapOf("name" to name, "date" to date))
                }
            }
        return birthdays
    }
}
